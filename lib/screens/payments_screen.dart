import 'package:flutter/material.dart';

import '../models/payment_models.dart';
import '../services/flutterwave_payment_service.dart';
import '../services/payment_region_service.dart';
import '../widgets/order_summary_widget.dart';
import '../widgets/payment_form_widget.dart';
import '../widgets/payment_method_selector.dart';
import 'payment_confirmation_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _billingNameController = TextEditingController(text: 'Amina Carter');
  final _emailController = TextEditingController(text: 'amina@example.com');
  final _phoneController = TextEditingController();
  final _paymentService = const FlutterwavePaymentService();

  PaymentCountry _country = PaymentRegionService.countries.first;
  late PaymentMethodOption _selectedMethod;
  bool _isProcessing = false;

  static const _items = [
    PaymentItem(name: 'Marketplace goods', quantity: 2, unitPrice: 85),
    PaymentItem(name: 'Service fee', quantity: 1, unitPrice: 18),
    PaymentItem(name: 'Buyer protection', quantity: 1, unitPrice: 6),
  ];
  static const _taxRate = 0.075;
  static const _discount = 10.0;

  @override
  void initState() {
    super.initState();
    _selectedMethod = PaymentRegionService.methodsFor(_country).first;
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _billingNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _items.fold(0, (total, item) => total + item.total);
  }

  double get _total {
    return (_subtotal + (_subtotal * _taxRate) - _discount)
        .clamp(0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final methods = PaymentRegionService.methodsFor(_country);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFE3F2F8),
              child:
                  Icon(Icons.shopping_bag_outlined, color: Color(0xFF0D3B66)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Goods and services checkout',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Accept regional cards, Mobile Money, and bank transfers through Flutterwave.',
                    style: TextStyle(color: Color(0xFF607080)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CountryCard(
          country: _country,
          countries: PaymentRegionService.countries,
          onChanged: _updateCountry,
        ),
        const SizedBox(height: 12),
        OrderSummaryWidget(
          items: _items,
          currencyCode: _country.currencyCode,
          taxRate: _taxRate,
          discount: _discount,
        ),
        const SizedBox(height: 12),
        PaymentMethodSelector(
          country: _country,
          methods: methods,
          selectedMethod: _selectedMethod,
          phoneController: _phoneController,
          onMethodChanged: (method) {
            setState(() => _selectedMethod = method);
          },
        ),
        const SizedBox(height: 12),
        PaymentFormWidget(
          formKey: _formKey,
          cardNumberController: _cardNumberController,
          expiryController: _expiryController,
          cvvController: _cvvController,
          billingNameController: _billingNameController,
          emailController: _emailController,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isProcessing ? null : _payNow,
          icon: _isProcessing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.payments_outlined),
          label: Text(_isProcessing ? 'Processing payment' : 'Pay now'),
        ),
      ],
    );
  }

  void _updateCountry(PaymentCountry country) {
    final methods = PaymentRegionService.methodsFor(country);
    setState(() {
      _country = country;
      if (!methods.any((method) => method.type == _selectedMethod.type)) {
        _selectedMethod = methods.first;
      }
    });
  }

  Future<void> _payNow() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final receipt = await _paymentService.processPayment(
        context: context,
        country: _country,
        method: _selectedMethod,
        billingName: _billingNameController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
        amount: _total,
      );

      if (!mounted) return;

      if (receipt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment was cancelled or failed.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment completed successfully.')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentConfirmationScreen(receipt: receipt),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Payment failed'),
          content: Text(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

class _CountryCard extends StatelessWidget {
  const _CountryCard({
    required this.country,
    required this.countries,
    required this.onChanged,
  });

  final PaymentCountry country;
  final List<PaymentCountry> countries;
  final ValueChanged<PaymentCountry> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DropdownButtonFormField<PaymentCountry>(
          isExpanded: true,
          initialValue: country,
          decoration: const InputDecoration(
            labelText: 'Customer country',
            prefixIcon: Icon(Icons.public_outlined),
          ),
          items: countries
              .map(
                (country) => DropdownMenuItem(
                  value: country,
                  child: Text(
                    '${country.name} - ${country.localTransferLabel}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}
