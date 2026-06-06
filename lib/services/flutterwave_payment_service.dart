import 'package:flutter/material.dart';
import 'package:flutterwave_standard/flutterwave.dart';

import '../models/payment_models.dart';

class FlutterwavePaymentService {
  const FlutterwavePaymentService();

  static const publicKey = String.fromEnvironment(
    'FLUTTERWAVE_PUBLIC_KEY',
    defaultValue: 'FLWPUBK_TEST-replace-with-your-public-key-X',
  );

  Future<PaymentReceipt?> processPayment({
    required BuildContext context,
    required PaymentCountry country,
    required PaymentMethodOption method,
    required String billingName,
    required String email,
    required String phoneNumber,
    required double amount,
  }) async {
    final txRef = _createTransactionReference(country);
    final customer = Customer(
      name: billingName.trim(),
      email: email.trim(),
      phoneNumber: '${country.dialCode}${phoneNumber.trim()}',
    );
    final flutterwave = Flutterwave(
      publicKey: publicKey,
      currency: country.currencyCode,
      amount: amount.toStringAsFixed(2),
      customer: customer,
      txRef: txRef,
      paymentOptions: method.flutterwaveOption,
      customization: Customization(
        title: 'INTERFLEX Goods and Services',
        description: 'Checkout for ${country.name}',
      ),
      redirectUrl: 'https://interflex.example/payment-complete',
      isTestMode: publicKey.contains('TEST'),
    );

    final response = await flutterwave.charge(context);
    if (response.success == true) {
      return PaymentReceipt(
        transactionId: response.txRef ?? txRef,
        amount: amount,
        currencyCode: country.currencyCode,
        country: country.name,
        date: DateTime.now(),
      );
    }

    return null;
  }

  String _createTransactionReference(PaymentCountry country) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'IFX-${country.isoCode}-$timestamp';
  }
}
