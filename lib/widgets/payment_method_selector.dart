import 'package:flutter/material.dart';

import '../models/payment_models.dart';

class PaymentMethodSelector extends StatelessWidget {
  const PaymentMethodSelector({
    super.key,
    required this.country,
    required this.methods,
    required this.selectedMethod,
    required this.phoneController,
    required this.onMethodChanged,
  });

  final PaymentCountry country;
  final List<PaymentMethodOption> methods;
  final PaymentMethodOption selectedMethod;
  final TextEditingController phoneController;
  final ValueChanged<PaymentMethodOption> onMethodChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment method',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...methods.map(
              (method) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MethodTile(
                  method: method,
                  selected: method.type == selectedMethod.type,
                  onTap: () => onMethodChanged(method),
                ),
              ),
            ),
            if (selectedMethod.type == PaymentMethodType.mobileMoney) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  SizedBox(
                    width: 104,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      child: Text(
                        country.dialCode,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: '${country.localTransferLabel} phone',
                        prefixIcon: const Icon(Icons.phone_android_outlined),
                      ),
                      validator: (value) {
                        if (selectedMethod.type !=
                            PaymentMethodType.mobileMoney) {
                          return null;
                        }
                        final digits =
                            (value ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 7) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethodOption method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final icon = switch (method.type) {
      PaymentMethodType.card => Icons.credit_card_outlined,
      PaymentMethodType.mobileMoney => Icons.phone_android_outlined,
      PaymentMethodType.bankTransfer => Icons.account_balance_outlined,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE3F2F8) : const Color(0xFFF6F8FB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? primary : const Color(0xFFD6DEE8),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.label,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    method.description,
                    style: const TextStyle(
                      color: Color(0xFF607080),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: primary,
            ),
          ],
        ),
      ),
    );
  }
}
