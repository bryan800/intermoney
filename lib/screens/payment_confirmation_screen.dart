import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/payment_models.dart';

class PaymentConfirmationScreen extends StatelessWidget {
  const PaymentConfirmationScreen({
    super.key,
    required this.receipt,
  });

  final PaymentReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      name: receipt.currencyCode,
      symbol: '${receipt.currencyCode} ',
      decimalDigits: _decimalDigits(receipt.currencyCode),
    );
    final date = DateFormat.yMMMd().add_jm().format(receipt.date);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment confirmed')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE3F8EF),
                      child: Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF00A676),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payment successful',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your goods and services payment has been processed.',
                      style: TextStyle(color: Color(0xFF607080)),
                    ),
                    const Divider(height: 28),
                    _ReceiptRow('Transaction ID', receipt.transactionId),
                    _ReceiptRow('Amount paid', money.format(receipt.amount)),
                    _ReceiptRow('Country', receipt.country),
                    _ReceiptRow('Date', date),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Receipt download prepared.')),
                );
              },
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download receipt'),
            ),
          ],
        ),
      ),
    );
  }

  int _decimalDigits(String currencyCode) {
    const zeroDecimalCurrencies = {'KES', 'NGN', 'RWF', 'TZS', 'UGX'};
    return zeroDecimalCurrencies.contains(currencyCode) ? 0 : 2;
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF607080)),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
