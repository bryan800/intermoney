import 'package:flutter/material.dart';

import 'login_screen.dart';
import '../services/payment_region_service.dart';
import '../utils/platform_gate.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const String _backgroundAssetMoney = 'uploads/money.png';
  static const String _backgroundAssetPng = 'assets/images/welcome_bg.png';
  static const String _backgroundAssetJpg = 'assets/images/welcome_bg.jpg';
  static const String _backgroundAssetJpeg = 'assets/images/welcome_bg.jpeg';

  Widget _fallbackGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF061F18),
            Color(0xFFF2F3F5),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Image.asset(
      _backgroundAssetMoney,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, error, __) {
        debugPrint(
            'Failed to load background asset "$_backgroundAssetMoney": $error');
        return Image.asset(
          _backgroundAssetPng,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, error, __) {
            debugPrint(
                'Failed to load background asset "$_backgroundAssetPng": $error');
            return Image.asset(
              _backgroundAssetJpg,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, error, __) {
                debugPrint(
                    'Failed to load background asset "$_backgroundAssetJpg": $error');
                return Image.asset(
                  _backgroundAssetJpeg,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, error, __) {
                    debugPrint(
                        'Failed to load background asset "$_backgroundAssetJpeg": $error');
                    return _fallbackGradient();
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _flagEmojiFromIso(String iso) {
    if (iso.length != 2) return '';

    const flagBase = 0x1F1E6;
    final codeUnits = iso.toUpperCase().codeUnits;
    if (codeUnits.any((c) => c < 0x41 || c > 0x5A)) return '';

    return String.fromCharCodes(codeUnits.map((c) => flagBase + (c - 0x41)));
  }

  void _goToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(initialCreateAccount: false),
      ),
    );
  }

  void _goToSignUp(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(initialCreateAccount: true),
      ),
    );
  }

  void _showExchangeRates(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFEFB).withAlpha(226),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Exchange rates',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Spacer(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: PaymentRegionService.regionalCountries.entries
                        .expand((entry) => [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              ...entry.value.map((country) {
                                final flag = _flagEmojiFromIso(country.isoCode);
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    '$flag ${country.name} '
                                    '(1 USD = ${country.usdExchangeRate} '
                                    '${country.currencyCode})',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    country.localTransferAgents.isEmpty
                                        ? 'Local method: Bank transfer'
                                        : 'Local methods: '
                                            '${country.localTransferAgents.join(', ')}',
                                  ),
                                );
                              }),
                              const Divider(height: 1),
                            ])
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          // Keep the photo visible while ensuring readable UI.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF061F18).withAlpha(150),
                  const Color(0xFF061F18).withAlpha(95),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF061F18).withAlpha(150),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'INTERFLEX',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF061F18).withAlpha(150),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextButton(
                          onPressed: () => _goToLogin(context),
                          child: const Text(
                            'Log in',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'FOR HERE\nFOR THERE\nFOR HOME',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: () => _goToSignUp(context),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child:
                            Text('or', style: TextStyle(color: Colors.black54)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isIOS) ...[
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => _goToLogin(context),
                        icon: const Icon(Icons.apple),
                        label: const Text(
                          'Continue with Apple',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _goToLogin(context),
                      icon: const Icon(Icons.mail_outline),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => _showExchangeRates(context),
                    child: const Text(
                      'Check rates and local methods',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
