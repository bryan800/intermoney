enum PaymentMethodType {
  card,
  mobileMoney,
  bankTransfer,
}

class PaymentItem {
  const PaymentItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final int quantity;
  final double unitPrice;

  double get total => quantity * unitPrice;
}

class PaymentMethodOption {
  const PaymentMethodOption({
    required this.type,
    required this.label,
    required this.description,
    required this.flutterwaveOption,
  });

  final PaymentMethodType type;
  final String label;
  final String description;
  final String flutterwaveOption;
}

class PaymentCountry {
  const PaymentCountry({
    required this.name,
    required this.region,
    required this.isoCode,
    required this.dialCode,
    required this.currencyCode,
    required this.usdExchangeRate,
    required this.localTransferAgents,
  });

  final String name;
  final String region;
  final String isoCode;
  final String dialCode;
  final String currencyCode;
  final double usdExchangeRate;
  final List<String> localTransferAgents;

  bool get supportsMobileMoney => localTransferAgents.isNotEmpty;

  String get localTransferLabel {
    if (localTransferAgents.isEmpty) return 'Local transfer';
    if (localTransferAgents.length == 1) return localTransferAgents.first;
    return localTransferAgents.take(2).join(' / ');
  }
}

class PaymentReceipt {
  const PaymentReceipt({
    required this.transactionId,
    required this.amount,
    required this.currencyCode,
    required this.country,
    required this.date,
  });

  final String transactionId;
  final double amount;
  final String currencyCode;
  final String country;
  final DateTime date;
}
