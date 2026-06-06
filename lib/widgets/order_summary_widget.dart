import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/payment_models.dart';

class OrderSummaryWidget extends StatelessWidget {
  const OrderSummaryWidget({
    super.key,
    required this.items,
    required this.currencyCode,
    required this.taxRate,
    required this.discount,
  });

  final List<PaymentItem> items;
  final String currencyCode;
  final double taxRate;
  final double discount;

  double get subtotal {
    return items.fold(0, (total, item) => total + item.total);
  }

  double get taxes {
    return subtotal * taxRate;
  }

  double get total {
    return (subtotal + taxes - discount).clamp(0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      name: currencyCode,
      symbol: '$currencyCode ',
      decimalDigits: _decimalDigits(currencyCode),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined),
                const SizedBox(width: 8),
                Text(
                  'Order summary',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => _SummaryRow(
                label: '${item.name} x${item.quantity}',
                value: money.format(item.total),
              ),
            ),
            const Divider(height: 24),
            _SummaryRow(label: 'Subtotal', value: money.format(subtotal)),
            _SummaryRow(label: 'Taxes', value: money.format(taxes)),
            _SummaryRow(label: 'Discount', value: '-${money.format(discount)}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _SummaryRow(
                label: 'Total',
                value: money.format(total),
                emphasized: true,
              ),
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
      fontSize: emphasized ? 16 : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasized ? Colors.black : const Color(0xFF607080),
                fontWeight: emphasized ? FontWeight.w900 : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
