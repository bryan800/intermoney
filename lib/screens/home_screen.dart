import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/auth_service.dart';
import '../services/exchange_rate_alert_service.dart';
import '../services/location_service.dart';
import '../services/live_chat_service.dart';
import '../services/payment_region_service.dart';
import '../services/sms_notification_service.dart';
import '../models/payment_models.dart';
import '../models/transaction_model.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';

const Color _appBackground = Color(0xFFF2F3F5);
const Color _appSurface = Color(0xFFFAFEFB);
const Color _appPrimary = Color(0xFF0E7A5F);
const Color _appSecondary = Color(0xFF0F9AA7);
const Color _appAmber = Color(0xFFF4B740);
const Color _appTextMuted = Color(0xFF60766B);
const Color _appOutline = Color(0xFFC9DCD0);

class _DestinationCountry {
  const _DestinationCountry({
    required this.country,
    required this.currency,
    required this.rate,
    required this.delivery,
    required this.rail,
  });

  final String country;
  final String currency;
  final double rate;
  final String delivery;
  final String rail;
}

class Recipient {
  final String name;
  final String number;
  final String country;
  final bool isGroup;
  Recipient(this.name, this.number, this.country, {this.isGroup = false});
}

class AppNotification {
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  final _amountController = TextEditingController(text: '1250');
  final _searchController = TextEditingController();

  final List<AppNotification> _notifications = [];
  String? _lastRateAlertId;

  final List<Recipient> _allRecipients = [
    Recipient('Anna Keller', '+49 123 456 789', 'Germany'),
    Recipient('John Doe', '+234 801 234 5678', 'Nigeria'),
    Recipient('Maria Garcia', '+52 55 1234 5678', 'Mexico'),
    Recipient('Family Support', 'Multi-recipient', 'Global', isGroup: true),
    Recipient('Peter Chen', '+86 10 1234 5678', 'China'),
    Recipient('Sarah Smith', '+44 20 1234 5678', 'UK'),
  ];

  List<Recipient> _filteredRecipients = [];

  @override
  void initState() {
    super.initState();
    _filteredRecipients = _allRecipients;
    _searchController.addListener(_filterRecipients);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ExchangeRateAlertService>().startMonitoring(
            _initialRateSnapshots(),
          );
    });

    // Request permissions
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    // Wait for the first frame to ensure context is ready for bottom sheets
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    // Check if PIN needs to be changed
    final authService = context.read<AuthService>();
    if (!authService.pinChanged) {
      _showMandatoryChangePinSheet();
    }

    // Request Location Permission
    await LocationService.requestLocationPermission();

    // Optional: Get initial location to "match live location"
    final position = await LocationService.getCurrentLocation();
    if (position != null) {
      _addNotification('Location Verified',
          'Live activity matched to your current location.');
    }
  }

  void _showMandatoryChangePinSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MandatoryChangePinSheet(
        onComplete: (title, msg) => _addNotification(title, msg),
      ),
    );
  }

  void _filterRecipients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRecipients = _allRecipients.where((r) {
        return r.name.toLowerCase().contains(query) ||
            r.number.toLowerCase().contains(query);
      }).toList();
    });
  }

  static const _destinations = [
    _DestinationCountry(
      country: 'Germany',
      currency: 'EUR',
      rate: 0.91,
      delivery: 'Instant SEPA',
      rail: 'SEPA / SWIFT',
    ),
    _DestinationCountry(
      country: 'United Kingdom',
      currency: 'GBP',
      rate: 0.78,
      delivery: 'Instant to 1 hour',
      rail: 'Faster Payments / SWIFT',
    ),
    _DestinationCountry(
      country: 'Nigeria',
      currency: 'NGN',
      rate: 1475.20,
      delivery: '10 minutes',
      rail: 'Bank / mobile wallet',
    ),
    _DestinationCountry(
      country: 'India',
      currency: 'INR',
      rate: 83.10,
      delivery: 'Instant to 2 hours',
      rail: 'UPI / bank transfer',
    ),
    _DestinationCountry(
      country: 'Philippines',
      currency: 'PHP',
      rate: 56.90,
      delivery: 'Instant to 1 hour',
      rail: 'Bank / cash pickup',
    ),
    _DestinationCountry(
      country: 'Mexico',
      currency: 'MXN',
      rate: 16.75,
      delivery: 'Under 30 minutes',
      rail: 'SPEI / cash pickup',
    ),
  ];

  List<ExchangeRateSnapshot> _initialRateSnapshots() {
    final snapshots = <String, ExchangeRateSnapshot>{};
    final now = DateTime.now();

    for (final dest in _destinations) {
      snapshots[dest.country] = ExchangeRateSnapshot(
        country: dest.country,
        currency: dest.currency,
        baselineRate: dest.rate,
        currentRate: dest.rate,
        previousRate: dest.rate,
        updatedAt: now,
      );
    }

    for (final countries in PaymentRegionService.regionalCountries.values) {
      for (final country in countries) {
        snapshots.putIfAbsent(
          country.name,
          () => ExchangeRateSnapshot(
            country: country.name,
            currency: country.currencyCode,
            baselineRate: country.usdExchangeRate,
            currentRate: country.usdExchangeRate,
            previousRate: country.usdExchangeRate,
            updatedAt: now,
          ),
        );
      }
    }

    return snapshots.values.toList();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _addNotification(String title, String message) {
    setState(() {
      _notifications.insert(
          0,
          AppNotification(
            title: title,
            message: message,
            timestamp: DateTime.now(),
          ));
    });
  }

  void _addSmsNotifications(List<SmsReceipt> receipts) {
    for (final receipt in receipts) {
      final statusLabel = receipt.status == SmsDeliveryStatus.queued
          ? 'SMS queued'
          : 'SMS sent';
      _addNotification(
        '$statusLabel to ${receipt.toNumber}',
        '${receipt.message}\nReference: ${receipt.reference}',
      );
    }
  }

  String _senderSmsNumber(AuthService authService) {
    return authService.accountNumber ?? AuthService.adminSupportNumber;
  }

  void _showNotifications() {
    setState(() {
      for (var n in _notifications) {
        n.isRead = true;
      }
    });
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: _notifications.isEmpty
                  ? const Center(child: Text('No new notifications'))
                  : ListView.separated(
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final n = _notifications[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(n.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.message),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat.jm().format(n.timestamp),
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _goHome() {
    if (_tabIndex == 0) return;
    setState(() => _tabIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    if (authService.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AdminDashboardScreen(),
          ),
        );
      });
    }

    final pages = [
      _homePage(context),
      _historyPage(context),
      _supportPage(context),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 780;

        return Scaffold(
          backgroundColor: _appBackground,
          appBar: AppBar(
            title: Semantics(
              button: true,
              label: 'Home',
              child: Tooltip(
                message: 'Home',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _goHome,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('INTERFLEX'),
                  ),
                ),
              ),
            ),
            backgroundColor: _appBackground,
            actions: [
              if (_tabIndex == 0) ...[
                Stack(
                  children: [
                    IconButton(
                      tooltip: 'Notifications',
                      icon: const Icon(Icons.notifications_none),
                      onPressed: _showNotifications,
                    ),
                    if (_notifications.any((n) => !n.isRead))
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                              color: _appAmber,
                              borderRadius: BorderRadius.circular(6)),
                          constraints:
                              const BoxConstraints(minWidth: 12, minHeight: 12),
                          child: Text(
                            '${_notifications.where((n) => !n.isRead).length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  tooltip: 'Logout',
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    context.read<AuthService>().logout();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          body: useRail
              ? Row(
                  children: [
                    NavigationRail(
                      backgroundColor: _appSurface.withAlpha(242),
                      indicatorColor: _appPrimary.withAlpha(40),
                      selectedIndex: _tabIndex,
                      onDestinationSelected: (value) =>
                          setState(() => _tabIndex = value),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: Text('Home'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.history),
                          selectedIcon: Icon(Icons.history),
                          label: Text('History'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.help_outline),
                          selectedIcon: Icon(Icons.help),
                          label: Text('Support'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: pages[_tabIndex]),
                  ],
                )
              : pages[_tabIndex],
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  backgroundColor: _appSurface.withAlpha(242),
                  indicatorColor: _appPrimary.withAlpha(40),
                  selectedIndex: _tabIndex,
                  onDestinationSelected: (value) =>
                      setState(() => _tabIndex = value),
                  destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: 'Home'),
                    NavigationDestination(
                        icon: Icon(Icons.history),
                        selectedIcon: Icon(Icons.history),
                        label: 'History'),
                    NavigationDestination(
                        icon: Icon(Icons.help_outline),
                        selectedIcon: Icon(Icons.help),
                        label: 'Support'),
                  ],
                ),
        );
      },
    );
  }

  Widget _homePage(BuildContext context) {
    final authService = context.watch<AuthService>();
    final rateService = context.watch<ExchangeRateAlertService>();
    _queueLatestRateNotification(rateService.latestAlert);
    final accountNumber = authService.accountNumber ?? 'Generating...';
    final userName = (authService.userName?.trim().isNotEmpty ?? false)
        ? authService.userName!.trim()
        : 'Customer';
    final currencySymbol = authService.currencySymbol;
    final userMoney = NumberFormat.currency(symbol: currencySymbol);
    final currentBalance = authService.balance;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            _WaveBalanceCard(
              money: userMoney,
              balance: currentBalance,
              userName: userName,
              accountNumber: accountNumber,
              onSend: () => _showSendToUserSheet(userMoney, currencySymbol),
              onScan: () => _showScanToPaySheet(userMoney, currencySymbol),
              onWithdraw: () => _showWithdrawSheet(userMoney, currencySymbol),
              onTax: () => _showTaxPaymentSheet(userMoney, currencySymbol),
              onHighValueTransfer: () =>
                  _showHighValueTransferSheet(userMoney, currencySymbol),
              onTopup: () => _showTopupSheet(userMoney, currencySymbol),
            ),
            _ExchangeRateMonitorPanel(
              isMonitoring: rateService.isMonitoring,
              rates: rateService.rates,
              onRefresh: rateService.refreshRates,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 10 : 16,
                4,
                isCompact ? 10 : 16,
                8,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Send to name or number',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear())
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: _appSurface,
                ),
              ),
            ),
            Expanded(
              child: _filteredRecipients.isEmpty
                  ? const Center(child: Text('No recipients found'))
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        isCompact ? 10 : 16,
                        12,
                        isCompact ? 10 : 16,
                        20,
                      ),
                      itemCount: _filteredRecipients.length +
                          (authService.recentTransactions.isEmpty ||
                                  _searchController.text.isNotEmpty
                              ? 0
                              : 1),
                      itemBuilder: (context, index) {
                        if (_searchController.text.isEmpty &&
                            authService.recentTransactions.isNotEmpty &&
                            index == 0) {
                          return _LatestTransactionsPreview(
                            transactions:
                                authService.recentTransactions.take(3).toList(),
                          );
                        }

                        final recipientIndex =
                            authService.recentTransactions.isNotEmpty &&
                                    _searchController.text.isEmpty
                                ? index - 1
                                : index;
                        final r = _filteredRecipients[recipientIndex];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (recipientIndex == 0 &&
                                _searchController.text.isEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(2, 2, 2, 12),
                                child: Text(
                                  'Recent recipients',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: _appTextMuted,
                                      ),
                                ),
                              ),
                            if (recipientIndex == 3 &&
                                _searchController.text.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'All contacts',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: _appTextMuted,
                                      ),
                                ),
                              ),
                            _RecipientTile(
                              name: r.name,
                              number: r.number,
                              country: r.country,
                              isGroup: r.isGroup,
                              onTap: () => _showTransferReview(r),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyPage(BuildContext context) {
    return _ResponsivePageList(
      children: const [
        _RecentActivityPanel(),
      ],
    );
  }

  Widget _supportPage(BuildContext context) {
    return _ResponsivePageList(
      children: [
        const _SectionHeader(
          title: 'How can we help?',
          subtitle: 'Our support team is available 24/7 to assist you.',
          icon: Icons.support_agent,
        ),
        const SizedBox(height: 20),
        _SupportActionTile(
          Icons.chat_bubble_outline,
          'Chat with us',
          'Instant help from our team',
          () => _showLiveChatSheet(context),
        ),
        const SizedBox(height: 12),
        _SupportActionTile(
          Icons.phone_outlined,
          'Call support',
          'Speak to an agent',
          () => _showCallSupportSheet(context),
        ),
        const SizedBox(height: 12),
        _SupportActionTile(
          Icons.email_outlined,
          'Email us',
          'support@interflex.com',
          () => _showEmailSupportSheet(context),
        ),
        const SizedBox(height: 24),
        Text('Security Settings',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: _appTextMuted)),
        const SizedBox(height: 12),
        _SupportActionTile(
            Icons.lock_outline,
            'Change Transaction PIN',
            'Update your 4-digit security PIN',
            () => _showChangePinSheet(context)),
      ],
    );
  }

  void _showLiveChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _LiveChatSheet(),
    );
  }

  void _showCallSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SupportContactSheet(
        icon: Icons.phone_outlined,
        title: 'Call support',
        subtitle: 'Our agents are available 24/7.',
        primaryText: AuthService.adminSupportNumber,
        primaryLabel: 'Copy admin number',
        copiedMessage: 'Admin number copied',
      ),
    );
  }

  void _showEmailSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SupportContactSheet(
        icon: Icons.email_outlined,
        title: 'Email support',
        subtitle: 'Send us your issue and account details.',
        primaryText: 'support@interflex.com',
        primaryLabel: 'Copy email',
        copiedMessage: 'Support email copied',
      ),
    );
  }

  void _showChangePinSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MandatoryChangePinSheet(
        isMandatory: false,
        onComplete: (title, msg) => _addNotification(title, msg),
      ),
    );
  }

  void _showSendToUserSheet(NumberFormat moneyFormatter, String symbol) {
    final authService = context.read<AuthService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SecureSendToUserFlow(
        money: moneyFormatter,
        currencySymbol: symbol,
        onComplete: (amountStr, country, account, isOfflineSim) async {
          _addNotification(
            isOfflineSim ? 'Offline Send Queued' : 'Send Successful',
            isOfflineSim
                ? 'Offline SIM transfer of $amountStr to $account in $country has been queued for mobile-network settlement.'
                : 'Successfully sent $amountStr to account $account in $country.',
          );
          if (_isValidMobileNumber(account)) {
            _addSmsNotifications(
              SmsNotificationService.sentMoneySms(
                senderNumber: _senderSmsNumber(authService),
                receiverNumber: _normalizedMobileNumber(account),
                amount: amountStr,
                senderAppId: authService.accountNumber ?? 'Unknown',
                isOffline: isOfflineSim,
                country: country,
              ),
            );
          }
        },
        onReversalRequest: () =>
            _showReversalSheet(TransactionType.send, symbol),
      ),
    );
  }

  void _showWithdrawSheet(NumberFormat moneyFormatter, String symbol) {
    final authService = context.read<AuthService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SecureWithdrawFlow(
        money: moneyFormatter,
        currencySymbol: symbol,
        onComplete: (amountStr, method, isOfflineSim) async {
          _addNotification(
            isOfflineSim ? 'Offline Withdrawal Queued' : 'Withdrawal Initiated',
            isOfflineSim
                ? 'Offline SIM withdrawal of $amountStr to $method has been queued for mobile-money payout.'
                : 'Withdrawal of $amountStr to $method is being processed.',
          );
          if (_isValidMobileNumber(method)) {
            _addSmsNotifications(
              SmsNotificationService.withdrawnMoneySms(
                senderNumber: _senderSmsNumber(authService),
                receiverNumber: _normalizedMobileNumber(method),
                amount: amountStr,
                senderAppId: authService.accountNumber ?? 'Unknown',
                isOffline: isOfflineSim,
                country: authService.userCountry,
              ),
            );
          }
        },
        onReversalRequest: () =>
            _showReversalSheet(TransactionType.withdraw, symbol),
      ),
    );
  }

  void _showScanToPaySheet(NumberFormat moneyFormatter, String symbol) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SecureScanToPayFlow(
        money: moneyFormatter,
        currencySymbol: symbol,
        onComplete: (amountStr, merchant) async {
          _addNotification(
              'Payment Sent', 'You paid $amountStr to Merchant ID: $merchant.');
        },
        onReversalRequest: () =>
            _showReversalSheet(TransactionType.pay, symbol),
      ),
    );
  }

  void _showTaxPaymentSheet(NumberFormat moneyFormatter, String symbol) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SecureTaxPaymentFlow(
        money: moneyFormatter,
        currencySymbol: symbol,
        onComplete: (amountStr, country, taxType, reference) async {
          _addNotification(
            'Tax Payment Successful',
            'Paid $amountStr for $taxType in $country. Reference: $reference.',
          );
        },
      ),
    );
  }

  void _showHighValueTransferSheet(NumberFormat moneyFormatter, String symbol) {
    final authService = context.read<AuthService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _HighValueTransferFlow(
        money: moneyFormatter,
        currencySymbol: symbol,
        onComplete: (amount, destination, purpose) async {
          try {
            await authService.updateBalance(-amount);
            authService.logTransaction(
              TransactionType.send,
              amount,
              destination,
              channel: 'High-value secure transfer - MFA + E2EE + AML',
            );
          } catch (error) {
            if (!mounted) return;
            _addNotification('Secure Transfer Failed', error.toString());
            showDialog(
              context: context,
              builder: (context) => _FailureDialog(message: error.toString()),
            );
            return;
          }

          if (!mounted) return;
          final amountStr = moneyFormatter.format(amount);
          _addNotification(
            'Secure Transfer Submitted',
            '$amountStr to $destination is protected by MFA, end-to-end encryption, and AML review.',
          );
          if (!sheetContext.mounted) return;
          Navigator.pop(sheetContext);
          showDialog(
            context: context,
            builder: (context) => _SuccessDialog(
              message:
                  '$amountStr high-value transfer to $destination has passed MFA and was submitted for strict AML review.\n\nPurpose: $purpose',
            ),
          );
        },
      ),
    );
  }

  void _showTopupSheet(NumberFormat moneyFormatter, String symbol) {
    final authService = context.read<AuthService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SecureTopupFlow(
        money: moneyFormatter,
        currencySymbol: symbol,
        homeCountry: authService.userCountry,
        onComplete: (amountStr, sourceLabel) async {
          final amount =
              double.tryParse(amountStr.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                  0.0;

          if (amount <= 0) {
            _addNotification('Topup Failed', 'Enter a valid top-up amount.');
            showDialog(
              context: context,
              builder: (context) => const _FailureDialog(
                message: 'Enter a valid top-up amount to continue.',
              ),
            );
            return;
          }

          await authService.updateBalance(amount);
          authService.logTransaction(
            TransactionType.topup,
            amount,
            sourceLabel,
          );
          if (!mounted) return;
          _addNotification('Topup Successful',
              'Successfully topped up $amountStr from $sourceLabel.');
          showDialog(
            context: context,
            builder: (context) => _SuccessDialog(
              message:
                  'You have successfully topped up $amountStr from $sourceLabel.',
            ),
          );
        },
      ),
    );
  }

  void _showReversalSheet(TransactionType type, String symbol) {
    Navigator.pop(context); // Close the current flow
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SecureReversalFlow(
        type: type,
        currencySymbol: symbol,
        onComplete: (title, msg) => _addNotification(title, msg),
      ),
    );
  }

  void _showTransferReview(Recipient recipient) {
    final authService = context.read<AuthService>();
    final rateService = context.read<ExchangeRateAlertService>();
    final currencySymbol = authService.currencySymbol;
    final userMoney = NumberFormat.currency(symbol: currencySymbol);

    final dest = _destinations.firstWhere((d) => d.country == recipient.country,
        orElse: () => _destinations.first);
    final rateSnapshot = rateService.rateForCountry(dest.country);
    final fxRate = rateSnapshot?.currentRate ?? dest.rate;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WaveTransferSheet(
        money: userMoney,
        currencySymbol: currencySymbol,
        recipientName: recipient.name,
        recipientCountry: recipient.country,
        fxRate: fxRate,
        rateSnapshot: rateSnapshot,
        currency: dest.currency,
        onComplete: (amount, currency) async {
          _addNotification('Transfer Sent',
              'You sent $currencySymbol ${userMoney.format(amount / fxRate).replaceAll(currencySymbol, '').trim()} to ${recipient.name} ($amount $currency received).');
          if (_isValidMobileNumber(recipient.number)) {
            _addSmsNotifications(
              SmsNotificationService.sentMoneySms(
                senderNumber: _senderSmsNumber(authService),
                receiverNumber: _normalizedMobileNumber(recipient.number),
                amount: '$amount $currency',
                senderAppId: authService.accountNumber ?? 'Unknown',
              ),
            );
          }
        },
      ),
    );
  }

  void _queueLatestRateNotification(ExchangeRateAlert? alert) {
    if (alert == null || alert.id == _lastRateAlertId) return;
    _lastRateAlertId = alert.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _addNotification(alert.title, alert.message);
    });
  }
}

class _WaveBalanceCard extends StatelessWidget {
  const _WaveBalanceCard({
    required this.money,
    required this.balance,
    required this.userName,
    required this.accountNumber,
    required this.onSend,
    required this.onScan,
    required this.onWithdraw,
    required this.onTax,
    required this.onHighValueTransfer,
    required this.onTopup,
  });
  final NumberFormat money;
  final double balance;
  final String userName;
  final String accountNumber;
  final VoidCallback onSend;
  final VoidCallback onScan;
  final VoidCallback onWithdraw;
  final VoidCallback onTax;
  final VoidCallback onHighValueTransfer;
  final VoidCallback onTopup;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 380;
        final horizontalPadding = isCompact ? 16.0 : 20.0;
        final balanceFontSize = isCompact ? 28.0 : 32.0;
        final accountFontSize = isCompact ? 11.0 : 12.0;
        final actionIconPadding = isCompact ? 9.0 : 10.0;

        return Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(
            isCompact ? 10 : 16,
            8,
            isCompact ? 10 : 16,
            10,
          ),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            isCompact ? 14 : 18,
            horizontalPadding,
            isCompact ? 14 : 18,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _appPrimary,
                _appSecondary,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _appPrimary.withAlpha(45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, $userName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Your balance',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Text(
                      'Account: $accountNumber',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: accountFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  money.format(balance),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: balanceFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 14 : 18),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runAlignment: WrapAlignment.center,
                spacing: isCompact ? 12 : 18,
                runSpacing: 12,
                children: [
                  _WaveQuickAction(
                    icon: Icons.send_outlined,
                    label: 'Send',
                    iconPadding: actionIconPadding,
                    onTap: onSend,
                  ),
                  _WaveQuickAction(
                    icon: Icons.qr_code_scanner,
                    label: 'Scan',
                    iconPadding: actionIconPadding,
                    onTap: onScan,
                  ),
                  _WaveQuickAction(
                    icon: Icons.account_balance_wallet,
                    label: 'Withdraw',
                    iconPadding: actionIconPadding,
                    onTap: onWithdraw,
                  ),
                  _WaveQuickAction(
                    icon: Icons.receipt_long_outlined,
                    label: 'Taxes',
                    iconPadding: actionIconPadding,
                    onTap: onTax,
                  ),
                  _WaveQuickAction(
                    icon: Icons.security_outlined,
                    label: 'Big transfer',
                    iconPadding: actionIconPadding,
                    width: isCompact ? 84 : 92,
                    onTap: onHighValueTransfer,
                  ),
                  _WaveQuickAction(
                    icon: Icons.add_circle_outline,
                    label: 'Topup',
                    iconPadding: actionIconPadding,
                    onTap: onTopup,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ResponsivePageList extends StatelessWidget {
  const _ResponsivePageList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _WaveQuickAction extends StatelessWidget {
  const _WaveQuickAction(
      {required this.icon,
      required this.label,
      required this.iconPadding,
      required this.onTap,
      this.width = 68});
  final IconData icon;
  final String label;
  final double iconPadding;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.black12,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(46),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(64)),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipientTile extends StatelessWidget {
  const _RecipientTile({
    required this.name,
    required this.number,
    required this.country,
    this.onTap,
    this.isGroup = false,
  });
  final String name;
  final String number;
  final String country;
  final VoidCallback? onTap;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE4F5F0),
        child: Icon(isGroup ? Icons.group : Icons.person, color: _appPrimary),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('$country • $number',
          style: const TextStyle(color: _appTextMuted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: _appTextMuted),
    );
  }
}

class _ExchangeRateMonitorPanel extends StatelessWidget {
  const _ExchangeRateMonitorPanel({
    required this.isMonitoring,
    required this.rates,
    required this.onRefresh,
  });

  final bool isMonitoring;
  final List<ExchangeRateSnapshot> rates;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final sortedRates = [...rates]
      ..sort((a, b) => b.changeFromBaseline.compareTo(a.changeFromBaseline));
    final bestRates = sortedRates.take(3).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _appOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isMonitoring ? Icons.notifications_active : Icons.radar,
                color: _appPrimary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Automatic rate detector',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed:
                    rates.isEmpty ? null : () => _showAllRatesSheet(context),
                icon: const Icon(Icons.public, size: 18),
                label: const Text('All rates'),
                style: TextButton.styleFrom(
                  foregroundColor: _appPrimary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Refresh rates',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (bestRates.isEmpty)
            const Text(
              'Starting live monitoring...',
              style: TextStyle(color: _appTextMuted, fontSize: 12),
            )
          else
            ...bestRates.map(_RateSignalRow.new),
        ],
      ),
    );
  }

  void _showAllRatesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AllExchangeRatesSheet(),
    );
  }
}

class _RateSignalRow extends StatelessWidget {
  const _RateSignalRow(this.rate);

  final ExchangeRateSnapshot rate;

  @override
  Widget build(BuildContext context) {
    final advice = _adviceText(rate.advice);
    final color = _adviceColor(rate.advice);
    final change = (rate.changeFromBaseline * 100).toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(_adviceIcon(rate.advice), color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${rate.country}: 1 USD = ${rate.formattedRate} ${rate.currency}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$change%  $advice',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllExchangeRatesSheet extends StatelessWidget {
  const _AllExchangeRatesSheet();

  @override
  Widget build(BuildContext context) {
    final rateService = context.watch<ExchangeRateAlertService>();
    final alphabeticalRates = [...rateService.rates]
      ..sort((a, b) => a.country.compareTo(b.country));

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _appSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _appOutline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
                child: Row(
                  children: [
                    Icon(
                      rateService.isMonitoring
                          ? Icons.notifications_active
                          : Icons.cloud_off_outlined,
                      color: _appPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Featured country rates',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            rateService.isMonitoring
                                ? '${alphabeticalRates.length} live USD rates'
                                : '${alphabeticalRates.length} saved USD rates',
                            style: const TextStyle(
                              color: _appTextMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh rates',
                      onPressed: rateService.refreshRates,
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: alphabeticalRates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return _CountryRateTile(alphabeticalRates[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CountryRateTile extends StatelessWidget {
  const _CountryRateTile(this.rate);

  final ExchangeRateSnapshot rate;

  @override
  Widget build(BuildContext context) {
    final advice = _adviceText(rate.advice);
    final color = _adviceColor(rate.advice);
    final change = (rate.changeFromBaseline * 100).toStringAsFixed(2);
    final flag = _flagEmojiForCountry(rate.country);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(26),
        foregroundColor: color,
        child: Text(
          flag.isEmpty ? rate.currency.substring(0, 1) : flag,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      title: Text(
        rate.country,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '1 USD = ${rate.formattedRate} ${rate.currency}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$change%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_adviceIcon(rate.advice), color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                advice,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _flagEmojiForCountry(String countryName) {
  final iso = PaymentRegionService.isoCodeForCountryName(countryName);
  if (iso == null || iso.length != 2) return '';

  const flagBase = 0x1F1E6;
  final codeUnits = iso.toUpperCase().codeUnits;
  if (codeUnits.any((c) => c < 0x41 || c > 0x5A)) return '';

  return String.fromCharCodes(codeUnits.map((c) => flagBase + (c - 0x41)));
}

class _RateAdviceCard extends StatelessWidget {
  const _RateAdviceCard({required this.rate});

  final ExchangeRateSnapshot rate;

  @override
  Widget build(BuildContext context) {
    final color = _adviceColor(rate.advice);
    final message = switch (rate.advice) {
      RateAdvice.transferNow =>
        'Best time to transfer: this rate is below your alert threshold.',
      RateAdvice.wait => 'Rate is high: wait if the transfer is not urgent.',
      RateAdvice.neutral =>
        'Rate is steady: safe to transfer when you are ready.',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_adviceIcon(rate.advice), color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _adviceText(rate.advice),
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(message, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _adviceText(RateAdvice advice) {
  return switch (advice) {
    RateAdvice.transferNow => 'Transfer now',
    RateAdvice.wait => 'Wait',
    RateAdvice.neutral => 'Steady',
  };
}

Color _adviceColor(RateAdvice advice) {
  return switch (advice) {
    RateAdvice.transferNow => _appPrimary,
    RateAdvice.wait => const Color(0xFFD94A3A),
    RateAdvice.neutral => _appSecondary,
  };
}

IconData _adviceIcon(RateAdvice advice) {
  return switch (advice) {
    RateAdvice.transferNow => Icons.trending_down,
    RateAdvice.wait => Icons.trending_up,
    RateAdvice.neutral => Icons.trending_flat,
  };
}

String _normalizedMobileNumber(String input) {
  final trimmed = input.trim();
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  return hasPlus ? '+$digits' : digits;
}

bool _isValidMobileNumber(String input) {
  final normalized = _normalizedMobileNumber(input);
  final digits = normalized.replaceAll('+', '');
  return digits.length >= 8 && digits.length <= 15;
}

class _OfflineSimNotice extends StatelessWidget {
  const _OfflineSimNotice({
    required this.enabled,
    required this.message,
  });

  final bool enabled;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _appAmber.withAlpha(130)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sim_card_outlined, color: _appAmber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF5F4A09)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.title, required this.subtitle, required this.icon});

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFE4F5F0),
          child: Icon(icon, color: _appPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: _appTextMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _appTextMuted),
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

class _OobVerificationPanel extends StatelessWidget {
  const _OobVerificationPanel({
    required this.controller,
    required this.isVerified,
    required this.onVerifiedChanged,
    required this.transactionSummary,
  });

  static const challengeCode = '742918';

  final TextEditingController controller;
  final bool isVerified;
  final ValueChanged<bool> onVerifiedChanged;
  final String transactionSummary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isVerified ? _appPrimary : _appOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVerified
                    ? Icons.verified_user
                    : Icons.phonelink_lock_outlined,
                color: _appPrimary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'E2EE + out-of-band verification',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            transactionSummary,
            style: const TextStyle(color: _appTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text(
            'Encrypted transaction details are checked against a trusted-channel code sent outside this app session. Confirm it before entering your PIN to block transaction tampering.',
            style: TextStyle(color: _appTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            'Demo OOB code: $challengeCode',
            style: const TextStyle(
              color: _appPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isVerified,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    counterText: '',
                    labelText: 'OOB code',
                    prefixIcon: Icon(Icons.password_outlined),
                  ),
                  onChanged: (_) => onVerifiedChanged(false),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: isVerified
                    ? null
                    : () {
                        final isValid = controller.text.trim() == challengeCode;
                        onVerifiedChanged(isValid);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isValid
                                ? 'OOB verification confirmed.'
                                : 'Incorrect OOB code. Check your trusted channel.'),
                            backgroundColor: isValid ? _appPrimary : Colors.red,
                          ),
                        );
                      },
                icon: Icon(
                    isVerified ? Icons.check_circle : Icons.verified_outlined),
                label: Text(isVerified ? 'Verified' : 'Verify'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

bool _requireOobVerification(
  BuildContext context,
  TextEditingController pinController,
  bool isVerified,
) {
  if (isVerified) return true;
  pinController.clear();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Complete out-of-band verification before authorizing.'),
      backgroundColor: Colors.red,
    ),
  );
  return false;
}

class _SupportActionTile extends StatelessWidget {
  const _SupportActionTile(this.icon, this.title, this.subtitle, [this.onTap]);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: _Panel(
        child: Row(
          children: [
            Icon(icon, color: _appPrimary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style:
                          const TextStyle(color: _appTextMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _SupportContactSheet extends StatelessWidget {
  const _SupportContactSheet({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryText,
    required this.primaryLabel,
    required this.copiedMessage,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String primaryText;
  final String primaryLabel;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomPadding),
        decoration: BoxDecoration(
          color: _appSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE4F5F0),
                  child: Icon(icon, color: _appPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(color: _appTextMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2FAF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _appOutline),
              ),
              child: SelectableText(
                primaryText,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: primaryText));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(copiedMessage)),
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.copy_outlined),
              label: Text(primaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveChatSheet extends StatefulWidget {
  const _LiveChatSheet();

  @override
  State<_LiveChatSheet> createState() => _LiveChatSheetState();
}

class _LiveChatSheetState extends State<_LiveChatSheet> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final auth = context.watch<AuthService>();
    final chat = context.watch<LiveChatService>();
    final accountNumber = auth.accountNumber ?? 'Unknown';
    final messages = chat.messagesForAccount(accountNumber);
    final hasMessages = messages.isNotEmpty;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: keyboardPadding),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.72,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _appSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE4F5F0),
                      child: Icon(Icons.support_agent, color: _appPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live chat',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Online support - Account $accountNumber',
                            style: const TextStyle(color: _appTextMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: hasMessages ? messages.length : 1,
                  itemBuilder: (context, index) {
                    if (!hasMessages) return const _SupportGreeting();
                    final message = messages[index];
                    final fromAgent = message.sentByAdmin;
                    return Column(
                      crossAxisAlignment: fromAgent
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: [
                        Align(
                          alignment: fromAgent
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 320),
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: fromAgent
                                  ? const Color(0xFFF2F7F4)
                                  : _appPrimary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              message.text,
                              style: TextStyle(
                                color: fromAgent
                                    ? const Color(0xFF17231E)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            DateFormat('h:mm a').format(message.sentAt),
                            style: const TextStyle(
                              color: _appTextMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (!auth.isAuthenticated)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Sign in to start a live support chat.',
                    style: TextStyle(color: _appTextMuted),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 3,
                        enabled: auth.isAuthenticated,
                        textInputAction: TextInputAction.send,
                        decoration: const InputDecoration(
                          hintText: 'Type your message',
                          prefixIcon: Icon(Icons.chat_bubble_outline),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: auth.isAuthenticated ? _sendMessage : null,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthService>();
    final chat = context.read<LiveChatService>();
    _messageController.clear();
    await chat.sendCustomerMessage(
      customerName: auth.userName ?? 'Customer',
      accountNumber: auth.accountNumber ?? 'Unknown',
      text: text,
    );
  }
}

class _SupportGreeting extends StatelessWidget {
  const _SupportGreeting();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F7F4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Hi, welcome to INTERFLEX support. Send a message and an admin will reply here.',
          style: TextStyle(color: Color(0xFF17231E)),
        ),
      ),
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel();

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final symbol = authService.currencySymbol;
    final balance = authService.balance;
    final transactions = authService.recentTransactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Activity',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        _ActivityRow(
            icon: Icons.account_balance_wallet,
            title: 'Current Wallet Balance',
            amount: '$symbol ${balance.toStringAsFixed(2)}',
            date: 'Live Status'),
        const Divider(),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'No transactions yet.',
              style: TextStyle(color: _appTextMuted),
            ),
          )
        else
          ...transactions.map((tx) => _ActivityRow.fromTransaction(tx)),
      ],
    );
  }
}

class _LatestTransactionsPreview extends StatelessWidget {
  const _LatestTransactionsPreview({required this.transactions});

  final List<TransactionRecord> transactions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest transactions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: _appTextMuted,
                ),
          ),
          const SizedBox(height: 8),
          ...transactions.map(_ActivityRow.fromTransaction),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(
      {required this.icon,
      required this.title,
      required this.amount,
      required this.date});

  factory _ActivityRow.fromTransaction(TransactionRecord tx) {
    final isCredit = tx.type == TransactionType.topup || tx.isReversed;
    final amountPrefix = isCredit ? '+' : '-';
    final title = switch (tx.type) {
      TransactionType.send => 'Sent to ${tx.destination}',
      TransactionType.pay => 'Paid ${tx.destination}',
      TransactionType.withdraw => 'Withdrew to ${tx.destination}',
      TransactionType.topup => 'Topup from ${tx.destination}',
    };
    final displayTitle = tx.isOfflinePending
        ? '$title (offline pending)'
        : tx.isReversed
            ? '$title (reversed)'
            : title;
    final displayDate = tx.isOfflinePending
        ? '${DateFormat('MMM d, h:mm a').format(tx.timestamp)} - ${tx.channel}'
        : DateFormat('MMM d, h:mm a').format(tx.timestamp);
    final icon = switch (tx.type) {
      TransactionType.send => Icons.arrow_outward,
      TransactionType.pay => Icons.storefront_outlined,
      TransactionType.withdraw => Icons.account_balance_wallet_outlined,
      TransactionType.topup => Icons.arrow_downward,
    };

    return _ActivityRow(
      icon: icon,
      title: displayTitle,
      amount:
          '$amountPrefix${tx.currency} ${NumberFormat('#,##0.00').format(tx.amount)}',
      date: displayDate,
    );
  }

  final IconData icon;
  final String title;
  final String amount;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[100],
            child: Icon(icon, color: Colors.black54, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(date,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Text(amount,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: amount.startsWith('+') ? Colors.green : Colors.black)),
        ],
      ),
    );
  }
}

class _WaveTransferSheet extends StatefulWidget {
  const _WaveTransferSheet({
    required this.money,
    required this.currencySymbol,
    required this.recipientName,
    required this.recipientCountry,
    required this.fxRate,
    required this.rateSnapshot,
    required this.currency,
    required this.onComplete,
  });

  final NumberFormat money;
  final String currencySymbol;
  final String recipientName;
  final String recipientCountry;
  final double fxRate;
  final ExchangeRateSnapshot? rateSnapshot;
  final String currency;
  final Function(double, String) onComplete;

  @override
  State<_WaveTransferSheet> createState() => _WaveTransferSheetState();
}

class _WaveTransferSheetState extends State<_WaveTransferSheet> {
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();
  final _oobController = TextEditingController();
  double _sendAmount = 0;
  bool _isVerifyingPin = false;
  bool _isOobVerified = false;

  @override
  void dispose() {
    _amountController.dispose();
    _pinController.dispose();
    _oobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerifyingPin) {
      return _buildPinStep();
    }

    final fee = (_sendAmount * 0.01).clamp(0.0, 50.0);
    final recipientGets = (_sendAmount - fee) * widget.fxRate;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue[50],
                child: const Icon(Icons.person, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.recipientName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(widget.recipientCountry,
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Amount to send',
              style: TextStyle(fontWeight: FontWeight.w500)),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '${widget.currencySymbol} ',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              fillColor: Colors.transparent,
            ),
            onChanged: (val) {
              setState(() {
                _sendAmount = double.tryParse(val) ?? 0;
              });
            },
          ),
          const Divider(),
          const SizedBox(height: 12),
          if (widget.rateSnapshot != null) ...[
            _RateAdviceCard(rate: widget.rateSnapshot!),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fee (1%)', style: TextStyle(color: Colors.grey[600])),
              Text(widget.money.format(fee)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${widget.recipientName} receives',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${recipientGets.toStringAsFixed(2)} ${widget.currency}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: _sendAmount > 0
                  ? () {
                      setState(() => _isVerifyingPin = true);
                    }
                  : null,
              child: const Text('Next',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinStep() {
    final authService = context.read<AuthService>();
    final fee = (_sendAmount * 0.01).clamp(0.0, 50.0);
    final recipientGets = (_sendAmount - fee) * widget.fxRate;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _isVerifyingPin = false)),
              const Text('Enter PIN',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _OobVerificationPanel(
            controller: _oobController,
            isVerified: _isOobVerified,
            transactionSummary:
                'Verify ${widget.money.format(_sendAmount)} to ${widget.recipientName} before decrypting and authorizing this transfer.',
            onVerifiedChanged: (value) =>
                setState(() => _isOobVerified = value),
          ),
          const SizedBox(height: 16),
          const Text('Confirm your transaction with your 4-digit PIN'),
          const SizedBox(height: 24),
          Pinput(
            length: 4,
            obscureText: true,
            controller: _pinController,
            onCompleted: (pin) async {
              if (!_requireOobVerification(
                  context, _pinController, _isOobVerified)) {
                return;
              }
              if (authService.verifyPin(pin)) {
                try {
                  await authService.updateBalance(
                      -recipientGets / widget.fxRate); // Debit sender
                  if (!mounted) return;
                  Navigator.pop(context);
                  widget.onComplete(recipientGets, widget.currency);
                  authService.logTransaction(TransactionType.send,
                      recipientGets / widget.fxRate, widget.recipientName);
                  _showSuccessDialog(context, widget.recipientName,
                      recipientGets, widget.currency);
                } catch (e) {
                  _pinController.clear();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red));
                  // Also add a notification for the failure
                  final homeState =
                      context.findAncestorStateOfType<_HomeScreenState>();
                  if (homeState != null) {
                    homeState._addNotification(
                        'Transaction Failed', e.toString());
                  }
                  Navigator.pop(context);
                }
              } else {
                _pinController.clear();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Invalid PIN. Transaction failed.'),
                    backgroundColor: Colors.red));
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showSuccessDialog(
      BuildContext context, String name, double amount, String currency) {
    showDialog(
      context: context,
      builder: (context) => _SuccessDialog(
        message:
            'You have successfully sent ${widget.money.format(amount).replaceAll(widget.currencySymbol, '').trim()} $currency to $name.',
      ),
    );
  }
}

class _SecureSendToUserFlow extends StatefulWidget {
  const _SecureSendToUserFlow(
      {required this.money,
      required this.currencySymbol,
      required this.onComplete,
      required this.onReversalRequest});
  final NumberFormat money;
  final String currencySymbol;
  final Function(String, String, String, bool) onComplete;
  final VoidCallback onReversalRequest;

  @override
  State<_SecureSendToUserFlow> createState() => _SecureSendToUserFlowState();
}

class _SecureSendToUserFlowState extends State<_SecureSendToUserFlow> {
  int _step = 1;
  String? _selectedRegion;
  String? _selectedCountry;
  String? _selectedCurrency;
  String? _selectedTransferMethod;
  double? _exchangeRate;
  double _amount = 0;
  bool _offlineSimMode = false;
  final _amountController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _destAccountController = TextEditingController();
  final _pinController = TextEditingController();
  final _oobController = TextEditingController();
  bool _isOobVerified = false;

  static const List<Map<String, String>> _verifiedRecipients = [
    {
      'country': 'Canada',
      'account': '6765566556656765',
      'name': 'Grace Morgan',
    },
    {
      'country': 'Germany',
      'account': '8812345678',
      'name': 'Anna Keller',
    },
    {
      'country': 'Nigeria',
      'account': '8823456789',
      'name': 'John Doe',
    },
    {
      'country': 'Mexico',
      'account': '8834567890',
      'name': 'Maria Garcia',
    },
  ];

  String _flagEmojiForCountry(String countryName) {
    final iso = PaymentRegionService.isoCodeForCountryName(countryName);
    if (iso == null || iso.length != 2) return '';

    const flagBase = 0x1F1E6;
    final codeUnits = iso.toUpperCase().codeUnits;
    if (codeUnits.any((c) => c < 0x41 || c > 0x5A)) return '';

    return String.fromCharCodes(
      codeUnits.map((c) => flagBase + (c - 0x41)),
    );
  }

  String _flagPrefix(String? countryName) {
    if (countryName == null) return '';
    final flag = _flagEmojiForCountry(countryName);
    return flag.isEmpty ? '' : '$flag ';
  }

  Map<String, List<PaymentCountry>> get _regionalCountries =>
      PaymentRegionService.regionalCountries;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateAmount);
    _recipientNameController.addListener(_refreshButtonState);
    _destAccountController.addListener(_refreshButtonState);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateAmount);
    _recipientNameController.removeListener(_refreshButtonState);
    _destAccountController.removeListener(_refreshButtonState);
    _amountController.dispose();
    _recipientNameController.dispose();
    _destAccountController.dispose();
    _pinController.dispose();
    _oobController.dispose();
    super.dispose();
  }

  void _updateAmount() {
    final normalized =
        _amountController.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final parsed = double.tryParse(normalized) ?? 0;
    if (parsed == _amount) return;
    setState(() => _amount = parsed);
  }

  void _refreshButtonState() {
    if (mounted) setState(() {});
  }

  Map<String, String>? get _verifiedRecipient {
    final account = _destAccountController.text.trim().replaceAll(' ', '');
    if (account.isEmpty || _selectedCountry == null) return null;

    for (final recipient in _verifiedRecipients) {
      if (recipient['country'] == _selectedCountry &&
          recipient['account'] == account) {
        return recipient;
      }
    }
    return null;
  }

  bool get _recipientNameMatches {
    final account = _destAccountController.text.trim();
    final name = _recipientNameController.text.trim();
    if (_offlineSimMode) return _isValidMobileNumber(account);
    if (account.isEmpty || name.isEmpty) return false;

    final verified = _verifiedRecipient;
    if (verified == null) return true;
    return verified['name']!.toLowerCase() == name.toLowerCase();
  }

  double get _sendFee => _amount * 0.01;
  double get _totalDebit => _amount + _sendFee;
  ExchangeRateSnapshot? get _selectedRateSnapshot {
    final country = _selectedCountry;
    if (country == null) return null;
    return context.read<ExchangeRateAlertService>().rateForCountry(country);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          if (_step == 1) _buildCountryStep(),
          if (_step == 2) _buildAmountStep(),
          if (_step == 3) _buildReviewStep(),
          if (_step == 4) _buildPinStep(),
          const SizedBox(height: 24),
          _buildButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title = 'Send Money';
    if (_step == 1) title = 'Select Destination';
    if (_step == 2) title = 'Enter Amount';
    if (_step == 3) title = 'Confirm Send';
    if (_step == 4) title = 'Enter PIN';

    return Row(
      children: [
        if (_step > 1)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _step--),
          ),
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildCountryStep() {
    return Column(
      children: [
        _buildRegionDropdown('Africa'),
        const SizedBox(height: 16),
        _buildRegionDropdown('North America'),
        if (_selectedCountry != null) ...[
          const SizedBox(height: 24),
          _Panel(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Selected', style: TextStyle(color: Colors.grey[600])),
                    Text(
                      '${_flagPrefix(_selectedCountry)}$_selectedCountry ($_selectedCurrency)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Exchange Rate',
                        style: TextStyle(color: Colors.grey[600])),
                    Text('1 USD = $_exchangeRate $_selectedCurrency',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Local methods',
                        style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _localTransferMethodsLabel(_selectedCountry!),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildRegionDropdown(String region) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: region,
        prefixIcon: Icon(region == 'Africa' ? Icons.public : Icons.map),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      initialValue: _selectedRegion == region ? _selectedCountry : null,
      items: _regionalCountries[region]!.map((country) {
        return DropdownMenuItem<String>(
          value: country.name,
          child: Text(
            '${_flagPrefix(country.name)}${country.name} '
            '- ${country.localTransferLabel}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          final countryData =
              _regionalCountries[region]!.firstWhere((c) => c.name == val);
          setState(() {
            _selectedRegion = region;
            _selectedCountry = val;
            _selectedCurrency = countryData.currencyCode;
            _exchangeRate = context
                    .read<ExchangeRateAlertService>()
                    .rateForCountry(val)
                    ?.currentRate ??
                countryData.usdExchangeRate;
            _selectedTransferMethod =
                PaymentRegionService.defaultTransferMethodForCountryName(val);
          });
        }
      },
    );
  }

  String _localTransferMethodsLabel(String countryName) {
    final methods = PaymentRegionService.transferAgentsForCountryName(
      countryName,
    );
    if (methods.isEmpty) return 'Bank transfer';
    return methods.join(', ');
  }

  Widget _buildAmountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sending to ${_flagPrefix(_selectedCountry)}$_selectedCountry',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        _buildTransferMethodDropdown(),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _offlineSimMode,
          onChanged: (value) => setState(() {
            _offlineSimMode = value;
            if (value) _selectedTransferMethod = 'Offline SIM number';
          }),
          title: const Text(
            'Use offline SIM number',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'Use when there is no internet. Enter a valid receiver mobile number.',
          ),
        ),
        TextField(
          controller: _destAccountController,
          keyboardType: _offlineSimMode ? TextInputType.phone : null,
          decoration: InputDecoration(
            labelText: _offlineSimMode
                ? 'Receiver mobile number'
                : 'Receiver account or phone',
            hintText: _offlineSimMode
                ? 'e.g. +256700123456'
                : 'e.g. 8812345678 or local wallet number',
            prefixIcon: Icon(
              _offlineSimMode
                  ? Icons.phone_android
                  : Icons.account_circle_outlined,
            ),
          ),
        ),
        if (!_offlineSimMode) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _recipientNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Receiver Full Name',
              hintText: 'Name on the receiver account',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
        ],
        _OfflineSimNotice(
          enabled: _offlineSimMode,
          message:
              'Offline SIM transfers are saved immediately and marked pending for mobile-network settlement. The receiver does not need this app.',
        ),
        const SizedBox(height: 8),
        _buildAccountVerificationNotice(),
        const SizedBox(height: 16),
        const Text('Amount to send',
            style: TextStyle(fontWeight: FontWeight.w500)),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: '0.00',
            prefixText: '${widget.currencySymbol} ',
            border: InputBorder.none,
            fillColor: Colors.transparent,
          ),
        ),
        if (_selectedCurrency != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'You are sending from your ${widget.currencySymbol} wallet. Recipient country currency: $_selectedCurrency.',
              style: const TextStyle(color: _appTextMuted, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final authService = context.watch<AuthService>();
    final remainingBalance = authService.balance - _totalDebit;
    final rateSnapshot = _selectedRateSnapshot;

    return Column(
      children: [
        _QuoteRow(
          'Receiver',
          _offlineSimMode
              ? _normalizedMobileNumber(_destAccountController.text)
              : _recipientNameController.text.trim(),
        ),
        _QuoteRow('Destination',
            '${_flagPrefix(_selectedCountry)}${_selectedCountry!}'),
        _QuoteRow('To Account', _destAccountController.text),
        _QuoteRow('Sent amount', widget.money.format(_amount)),
        _QuoteRow('Transfer charge', widget.money.format(_sendFee)),
        _QuoteRow('Total deducted', widget.money.format(_totalDebit)),
        _QuoteRow('Balance after', widget.money.format(remainingBalance)),
        _QuoteRow('Method', _selectedTransferMethod ?? 'Bank transfer'),
        if (_offlineSimMode)
          const _QuoteRow('Offline mode', 'SIM mobile-number transfer'),
        if (_exchangeRate != null && _selectedCurrency != null)
          _QuoteRow(
            'Exchange rate',
            '1 USD = ${_exchangeRate!.toStringAsFixed(_exchangeRate! >= 100 ? 2 : 4)} $_selectedCurrency',
          ),
        if (rateSnapshot != null) ...[
          const SizedBox(height: 12),
          _RateAdviceCard(rate: rateSnapshot),
        ],
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.shield, color: Colors.green, size: 16),
            SizedBox(width: 8),
            Text('Securely encrypted by INTERFLEX',
                style: TextStyle(color: Colors.green, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildButton() {
    if (_step == 1) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedCountry == null
                  ? null
                  : () => setState(() => _step = 2),
              child: const Text('Continue to Details'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: widget.onReversalRequest,
            icon: const Icon(Icons.history_outlined, size: 16),
            label: const Text('Reverse a wrong transaction'),
          ),
        ],
      );
    }
    if (_step == 4) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16)),
        onPressed: !_canContinueCurrentStep()
            ? null
            : () {
                if (_step < 3) {
                  setState(() => _step++);
                } else {
                  setState(() => _step = 4);
                }
              },
        child: Text(_step == 3 ? 'Confirm & Authenticate' : 'Next'),
      ),
    );
  }

  bool _canContinueCurrentStep() {
    if (_step == 2) {
      return _amount > 0 &&
          _recipientNameMatches &&
          (!_offlineSimMode ||
              _isValidMobileNumber(_destAccountController.text));
    }
    if (_step == 3) {
      return _amount > 0 &&
          _recipientNameMatches &&
          (!_offlineSimMode ||
              _isValidMobileNumber(_destAccountController.text));
    }
    return true;
  }

  Widget _buildTransferMethodDropdown() {
    final country = _selectedCountry;
    if (country == null) return const SizedBox.shrink();

    final methods = PaymentRegionService.transferAgentsForCountryName(country);
    final options = methods.isEmpty ? const ['Bank transfer'] : methods;

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Receiver payout method',
        prefixIcon: const Icon(Icons.swap_horiz_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      initialValue: options.contains(_selectedTransferMethod)
          ? _selectedTransferMethod
          : options.first,
      items: options
          .map(
            (method) => DropdownMenuItem<String>(
              value: method,
              child: Text(method, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedTransferMethod = value);
        }
      },
    );
  }

  Widget _buildAccountVerificationNotice() {
    final account = _destAccountController.text.trim();
    final name = _recipientNameController.text.trim();
    if (_offlineSimMode) {
      if (account.isEmpty) return const SizedBox.shrink();
      return Text(
        _isValidMobileNumber(account)
            ? 'Valid mobile number for offline SIM transfer.'
            : 'Enter a valid mobile number with 8 to 15 digits.',
        style: TextStyle(
          color: _isValidMobileNumber(account) ? _appPrimary : _appAmber,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    if (account.isEmpty || name.isEmpty) {
      return const SizedBox.shrink();
    }

    final verified = _verifiedRecipient;
    if (verified == null) {
      return const Text(
        'Receiver details accepted.',
        style: TextStyle(
          color: _appPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    if (!_recipientNameMatches) {
      return const Text(
        'Account found. Receiver name must match the account holder.',
        style: TextStyle(color: _appAmber, fontSize: 12),
      );
    }

    return Text(
      'Verified: ${verified['name']}',
      style: const TextStyle(
        color: _appPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildPinStep() {
    final authService = context.read<AuthService>();
    return Column(
      children: [
        _OobVerificationPanel(
          controller: _oobController,
          isVerified: _isOobVerified,
          transactionSummary:
              'Verify ${widget.money.format(_amount)} to ${_recipientNameController.text.trim()} on ${_selectedTransferMethod ?? 'Online'} before authorizing.',
          onVerifiedChanged: (value) => setState(() => _isOobVerified = value),
        ),
        const SizedBox(height: 16),
        const Text('Confirm your transfer with your 4-digit PIN'),
        const SizedBox(height: 24),
        Pinput(
          length: 4,
          obscureText: true,
          controller: _pinController,
          onCompleted: (pin) async {
            if (!_requireOobVerification(
                context, _pinController, _isOobVerified)) {
              return;
            }
            if (authService.verifyPin(pin)) {
              try {
                final balanceAfter = authService.balance - _totalDebit;
                await authService.updateBalance(-_totalDebit);
                if (!mounted) return;
                authService.logTransaction(
                  TransactionType.send,
                  _totalDebit,
                  _offlineSimMode
                      ? 'Offline SIM transfer to ${_normalizedMobileNumber(_destAccountController.text)}'
                      : '${_recipientNameController.text.trim()} - '
                          '${_selectedTransferMethod ?? 'Bank transfer'} - '
                          '${_destAccountController.text.trim()}',
                  isOfflinePending: _offlineSimMode,
                  channel: _offlineSimMode
                      ? 'Offline SIM number'
                      : _selectedTransferMethod ?? 'Online',
                );
                _handleSuccess(balanceAfter);
              } catch (e) {
                _pinController.clear();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString()), backgroundColor: Colors.red));
                // Add notification to _HomeScreenState
                final homeState =
                    context.findAncestorStateOfType<_HomeScreenState>();
                if (homeState != null) {
                  homeState._addNotification(
                      'Transaction Failed', e.toString());
                }
                Navigator.pop(context);
              }
            } else {
              _pinController.clear();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Invalid PIN. Transaction failed.'),
                  backgroundColor: Colors.red));
              Navigator.pop(context);
            }
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _handleSuccess(double balanceAfter) {
    if (!mounted) return;
    final recipientName = _offlineSimMode
        ? _normalizedMobileNumber(_destAccountController.text)
        : _recipientNameController.text.trim();
    final account = _offlineSimMode
        ? _normalizedMobileNumber(_destAccountController.text)
        : _destAccountController.text.trim();
    Navigator.pop(context);
    widget.onComplete(
      widget.money.format(_amount),
      _selectedCountry!,
      account,
      _offlineSimMode,
    );
    final statusLine = _offlineSimMode
        ? 'Status: queued offline for SIM/mobile-number settlement\n'
        : '';
    showDialog(
      context: context,
      builder: (context) => _SuccessDialog(
        message: 'Sent ${widget.money.format(_amount)} to $recipientName.\n'
            'Method: ${_offlineSimMode ? 'Offline SIM number' : _selectedTransferMethod ?? 'Bank transfer'}\n'
            '$statusLine'
            'Account: $account\n'
            'Charge: ${widget.money.format(_sendFee)}\n'
            'Total deducted: ${widget.money.format(_totalDebit)}\n'
            'Balance left: ${widget.money.format(balanceAfter)}',
      ),
    );
  }
}

class _SecureWithdrawFlow extends StatefulWidget {
  const _SecureWithdrawFlow(
      {required this.money,
      required this.currencySymbol,
      required this.onComplete,
      required this.onReversalRequest});
  final NumberFormat money;
  final String currencySymbol;
  final Function(String, String, bool) onComplete;
  final VoidCallback onReversalRequest;

  @override
  State<_SecureWithdrawFlow> createState() => _SecureWithdrawFlowState();
}

class _SecureWithdrawFlowState extends State<_SecureWithdrawFlow> {
  int _step = 1;
  String? _selectedMethod;
  double _amount = 0;
  bool get _isOfflineMobileWithdraw =>
      _selectedMethod == 'Offline SIM mobile number';
  final _amountController = TextEditingController();
  final _detailsController = TextEditingController();
  final _pinController = TextEditingController();
  final _oobController = TextEditingController();
  bool _isOobVerified = false;

  @override
  void dispose() {
    _detailsController.removeListener(_refreshButtonState);
    _amountController.dispose();
    _detailsController.dispose();
    _pinController.dispose();
    _oobController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _detailsController.addListener(_refreshButtonState);
  }

  void _refreshButtonState() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          if (_step == 1) _buildMethodStep(),
          if (_step == 2) _buildDetailsStep(),
          if (_step == 3) _buildReviewStep(),
          if (_step == 4) _buildPinStep(),
          const SizedBox(height: 24),
          _buildButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title = 'Withdraw';
    if (_step == 1) title = 'Select Payout Method';
    if (_step == 2) title = 'Enter Details';
    if (_step == 3) title = 'Confirm Withdrawal';
    if (_step == 4) title = 'Enter PIN';

    return Row(
      children: [
        if (_step > 1)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _step--),
          ),
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildMethodStep() {
    final methods = [
      {'name': 'Bank Account', 'icon': Icons.account_balance},
      {'name': 'Mobile Money', 'icon': Icons.phone_android},
      {'name': 'Offline SIM mobile number', 'icon': Icons.sim_card_outlined},
      {'name': 'Debit Card', 'icon': Icons.credit_card},
    ];
    return Column(
      children: methods
          .map((m) => ListTile(
                leading: Icon(m['icon'] as IconData),
                title: Text(m['name'] as String),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _selectedMethod = m['name'] as String;
                    _step = 2;
                  });
                },
              ))
          .toList(),
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Withdraw to $_selectedMethod',
            style: TextStyle(color: Colors.grey[600])),
        TextField(
          controller: _detailsController,
          keyboardType: _isOfflineMobileWithdraw
              ? TextInputType.phone
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: _isOfflineMobileWithdraw
                ? 'Mobile number'
                : 'Destination details',
            hintText: _selectedMethod == 'Bank Account'
                ? 'Account Number'
                : 'e.g. +256700123456',
            prefixIcon: Icon(
              _isOfflineMobileWithdraw
                  ? Icons.sim_card_outlined
                  : Icons.account_circle_outlined,
            ),
          ),
        ),
        _OfflineSimNotice(
          enabled: _isOfflineMobileWithdraw,
          message:
              'Use this when there is no internet. The app debits your balance and marks the withdrawal pending for SIM/mobile-money payout to any valid mobile number.',
        ),
        if (_detailsController.text.trim().isNotEmpty &&
            (_selectedMethod == 'Mobile Money' || _isOfflineMobileWithdraw))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _isValidMobileNumber(_detailsController.text)
                  ? 'Valid mobile number.'
                  : 'Enter a valid mobile number with 8 to 15 digits.',
              style: TextStyle(
                color: _isValidMobileNumber(_detailsController.text)
                    ? _appPrimary
                    : _appAmber,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text('Amount to withdraw',
            style: TextStyle(fontWeight: FontWeight.w500)),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: '0.00',
            prefixText: '${widget.currencySymbol} ',
            border: InputBorder.none,
            fillColor: Colors.transparent,
          ),
          onChanged: (val) =>
              setState(() => _amount = double.tryParse(val) ?? 0),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      children: [
        _QuoteRow('Method', _selectedMethod!),
        _QuoteRow(
          'Details',
          _isOfflineMobileWithdraw
              ? _normalizedMobileNumber(_detailsController.text)
              : _detailsController.text,
        ),
        _QuoteRow('Amount', widget.money.format(_amount)),
        _QuoteRow('Fee', '${widget.currencySymbol}0.00'),
        if (_isOfflineMobileWithdraw)
          const _QuoteRow('Offline mode', 'SIM/mobile-number payout'),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.lock, color: Colors.blue, size: 16),
            SizedBox(width: 8),
            Text('Protected by multi-factor authentication',
                style: TextStyle(color: Colors.blue, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildButton() {
    if (_step == 1) {
      return Column(
        children: [
          const SizedBox.shrink(),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: widget.onReversalRequest,
            icon: const Icon(Icons.history_outlined, size: 16),
            label: const Text('Reverse a wrong withdrawal'),
          ),
        ],
      );
    }
    if (_step == 4) return const SizedBox.shrink();
    bool canProceed = _amount > 0;
    if (_step == 2) {
      canProceed = _amount > 0 &&
          _detailsController.text.isNotEmpty &&
          (!_isOfflineMobileWithdraw ||
              _isValidMobileNumber(_detailsController.text));
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16)),
        onPressed: !canProceed
            ? null
            : () {
                if (_step < 3) {
                  setState(() => _step++);
                } else {
                  setState(() => _step = 4);
                }
              },
        child: Text(_step == 3 ? 'Confirm & Withdraw' : 'Next'),
      ),
    );
  }

  Widget _buildPinStep() {
    final authService = context.read<AuthService>();
    return Column(
      children: [
        _OobVerificationPanel(
          controller: _oobController,
          isVerified: _isOobVerified,
          transactionSummary:
              'Verify withdrawal of ${widget.money.format(_amount)} to ${_isOfflineMobileWithdraw ? _normalizedMobileNumber(_detailsController.text) : _selectedMethod ?? 'selected method'} before authorizing.',
          onVerifiedChanged: (value) => setState(() => _isOobVerified = value),
        ),
        const SizedBox(height: 16),
        const Text('Confirm your withdrawal with your 4-digit PIN'),
        const SizedBox(height: 24),
        Pinput(
          length: 4,
          obscureText: true,
          controller: _pinController,
          onCompleted: (pin) async {
            if (!_requireOobVerification(
                context, _pinController, _isOobVerified)) {
              return;
            }
            if (authService.verifyPin(pin)) {
              try {
                await authService.updateBalance(-_amount);
                if (!mounted) return;
                authService.logTransaction(
                  TransactionType.withdraw,
                  _amount,
                  _isOfflineMobileWithdraw
                      ? 'Offline SIM withdrawal to ${_normalizedMobileNumber(_detailsController.text)}'
                      : _selectedMethod!,
                  isOfflinePending: _isOfflineMobileWithdraw,
                  channel: _isOfflineMobileWithdraw
                      ? 'Offline SIM number'
                      : 'Online',
                );
                _handleSuccess();
              } catch (e) {
                _pinController.clear();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString()), backgroundColor: Colors.red));
                // Add notification to _HomeScreenState
                final homeState =
                    context.findAncestorStateOfType<_HomeScreenState>();
                if (homeState != null) {
                  homeState._addNotification(
                      'Transaction Failed', e.toString());
                }
                Navigator.pop(context);
              }
            } else {
              _pinController.clear();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Invalid PIN. Transaction failed.'),
                  backgroundColor: Colors.red));
              Navigator.pop(context);
            }
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _handleSuccess() {
    if (!mounted) return;
    Navigator.pop(context);
    final destination = _isOfflineMobileWithdraw
        ? _normalizedMobileNumber(_detailsController.text)
        : _selectedMethod!;
    widget.onComplete(
      widget.money.format(_amount),
      destination,
      _isOfflineMobileWithdraw,
    );
    showDialog(
      context: context,
      builder: (context) => _SuccessDialog(
        message: _isOfflineMobileWithdraw
            ? 'Withdrawal of ${widget.money.format(_amount)} to $destination has been queued offline for SIM/mobile-money payout.'
            : 'Withdrawal of ${widget.money.format(_amount)} to $_selectedMethod successful.',
      ),
    );
  }
}

class _SecureTaxPaymentFlow extends StatefulWidget {
  const _SecureTaxPaymentFlow({
    required this.money,
    required this.currencySymbol,
    required this.onComplete,
  });

  final NumberFormat money;
  final String currencySymbol;
  final Function(String, String, String, String) onComplete;

  @override
  State<_SecureTaxPaymentFlow> createState() => _SecureTaxPaymentFlowState();
}

class _SecureTaxPaymentFlowState extends State<_SecureTaxPaymentFlow> {
  static const _taxTypes = [
    'Income tax',
    'VAT / GST',
    'Property tax',
    'Business tax',
    'Customs duty',
    'Vehicle tax',
    'Payroll tax',
    'Withholding tax',
    'Excise tax',
    'Other government tax',
  ];

  int _step = 1; // 1: Country/type, 2: Details, 3: Review, 4: PIN
  late PaymentCountry _selectedCountry;
  String _selectedTaxType = _taxTypes.first;
  double _amount = 0;
  final _taxpayerIdController = TextEditingController();
  final _billReferenceController = TextEditingController();
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();
  final _oobController = TextEditingController();
  bool _isOobVerified = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _selectedCountry =
        PaymentRegionService.countryByName(auth.userCountry ?? '') ??
            PaymentRegionService.countries.first;
    _taxpayerIdController.addListener(_refreshButtonState);
    _billReferenceController.addListener(_refreshButtonState);
  }

  @override
  void dispose() {
    _taxpayerIdController.removeListener(_refreshButtonState);
    _billReferenceController.removeListener(_refreshButtonState);
    _taxpayerIdController.dispose();
    _billReferenceController.dispose();
    _amountController.dispose();
    _pinController.dispose();
    _oobController.dispose();
    super.dispose();
  }

  void _refreshButtonState() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            if (_step == 1) _buildTaxSelectionStep(),
            if (_step == 2) _buildDetailsStep(),
            if (_step == 3) _buildReviewStep(),
            if (_step == 4) _buildPinStep(),
            const SizedBox(height: 24),
            _buildButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = 'Pay Taxes';
    if (_step == 2) title = 'Tax Details';
    if (_step == 3) title = 'Review Tax Payment';
    if (_step == 4) title = 'Enter PIN';

    return Row(
      children: [
        if (_step > 1)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _step--),
          ),
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildTaxSelectionStep() {
    final countries = PaymentRegionService.countries.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select the country and tax category. Payment will be debited directly from your INTERFLEX account.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<PaymentCountry>(
          initialValue: _selectedCountry,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Tax country',
            prefixIcon: Icon(Icons.public_outlined),
          ),
          items: countries
              .map(
                (country) => DropdownMenuItem(
                  value: country,
                  child: Text(
                    '${_flagPrefix(country)}${country.name} (${country.currencyCode})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (country) {
            if (country == null) return;
            setState(() => _selectedCountry = country);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedTaxType,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Tax type',
            prefixIcon: Icon(Icons.receipt_long_outlined),
          ),
          items: _taxTypes
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(type),
                ),
              )
              .toList(),
          onChanged: (type) {
            if (type == null) return;
            setState(() => _selectedTaxType = type);
          },
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paying $_selectedTaxType in ${_selectedCountry.name}',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _taxpayerIdController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Taxpayer ID / TIN',
            hintText: 'Enter taxpayer identification',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _billReferenceController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Assessment / bill reference',
            hintText: 'Enter tax bill or assessment number',
            prefixIcon: Icon(Icons.confirmation_number_outlined),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Amount to pay',
            style: TextStyle(fontWeight: FontWeight.w500)),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: '0.00',
            prefixText: '${widget.currencySymbol} ',
            border: InputBorder.none,
            fillColor: Colors.transparent,
          ),
          onChanged: (value) {
            final parsed = double.tryParse(
                  value.replaceAll(RegExp(r'[^0-9.]'), ''),
                ) ??
                0;
            setState(() => _amount = parsed);
          },
        ),
        Text(
          'Authority: ${_selectedCountry.name} revenue authority',
          style: const TextStyle(color: _appTextMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      children: [
        _QuoteRow('Country', _selectedCountry.name),
        _QuoteRow('Tax type', _selectedTaxType),
        _QuoteRow('Taxpayer ID', _taxpayerIdController.text.trim()),
        _QuoteRow('Reference', _billReferenceController.text.trim()),
        _QuoteRow('Amount', widget.money.format(_amount)),
        _QuoteRow('Fee', '${widget.currencySymbol}0.00'),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.lock, color: Colors.green, size: 16),
            SizedBox(width: 8),
            Text('Direct account debit secured by INTERFLEX PIN',
                style: TextStyle(color: Colors.green, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildPinStep() {
    final authService = context.read<AuthService>();
    return Column(
      children: [
        _OobVerificationPanel(
          controller: _oobController,
          isVerified: _isOobVerified,
          transactionSummary:
              'Verify tax payment of ${widget.money.format(_amount)} for $_selectedTaxType, reference ${_billReferenceController.text.trim()}.',
          onVerifiedChanged: (value) => setState(() => _isOobVerified = value),
        ),
        const SizedBox(height: 16),
        const Text('Confirm this tax payment with your 4-digit app PIN'),
        const SizedBox(height: 24),
        Pinput(
          length: 4,
          obscureText: true,
          controller: _pinController,
          onCompleted: (pin) async {
            if (!_requireOobVerification(
                context, _pinController, _isOobVerified)) {
              return;
            }
            if (!authService.verifyPin(pin)) {
              _pinController.clear();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Invalid PIN. Tax payment failed.'),
                  backgroundColor: Colors.red));
              Navigator.pop(context);
              return;
            }

            try {
              await authService.updateBalance(-_amount);
              if (!mounted) return;
              authService.logTransaction(
                TransactionType.pay,
                _amount,
                'Tax payment: $_selectedTaxType - ${_selectedCountry.name} - ${_billReferenceController.text.trim()}',
                channel: 'Tax payment',
              );
              _handleSuccess();
            } catch (e) {
              _pinController.clear();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(e.toString()), backgroundColor: Colors.red));
              final homeState =
                  context.findAncestorStateOfType<_HomeScreenState>();
              homeState?._addNotification('Tax Payment Failed', e.toString());
              Navigator.pop(context);
            }
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildButton() {
    bool canProceed = true;
    if (_step == 2) {
      canProceed = _taxpayerIdController.text.trim().length >= 4 &&
          _billReferenceController.text.trim().length >= 4 &&
          _amount > 0;
    }
    if (_step == 4) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16)),
        onPressed: !canProceed
            ? null
            : () {
                if (_step < 3) {
                  setState(() => _step++);
                } else {
                  setState(() => _step = 4);
                }
              },
        child: Text(_step == 3 ? 'Confirm & Pay Tax' : 'Next'),
      ),
    );
  }

  void _handleSuccess() {
    if (!mounted) return;
    final reference = _billReferenceController.text.trim();
    Navigator.pop(context);
    widget.onComplete(
      widget.money.format(_amount),
      _selectedCountry.name,
      _selectedTaxType,
      reference,
    );
    showDialog(
      context: context,
      builder: (context) => _SuccessDialog(
        message:
            'You have successfully paid ${widget.money.format(_amount)} for $_selectedTaxType in ${_selectedCountry.name}.\nReference: $reference',
      ),
    );
  }

  String _flagPrefix(PaymentCountry country) {
    final iso = country.isoCode;
    if (iso.length != 2) return '';

    const flagBase = 0x1F1E6;
    final codeUnits = iso.toUpperCase().codeUnits;
    if (codeUnits.any((c) => c < 0x41 || c > 0x5A)) return '';

    return '${String.fromCharCodes(codeUnits.map((c) => flagBase + (c - 0x41)))} ';
  }
}

class _SecureScanToPayFlow extends StatefulWidget {
  const _SecureScanToPayFlow(
      {required this.money,
      required this.currencySymbol,
      required this.onComplete,
      required this.onReversalRequest});
  final NumberFormat money;
  final String currencySymbol;
  final Function(String, String) onComplete;
  final VoidCallback onReversalRequest;

  @override
  State<_SecureScanToPayFlow> createState() => _SecureScanToPayFlowState();
}

class _SecureScanToPayFlowState extends State<_SecureScanToPayFlow> {
  int _step = 1; // 1: Select Method/Scan, 2: Amount, 3: Confirm, 4: PIN
  String _merchantCode = '';
  double _amount = 0;
  final _codeController = TextEditingController();
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();
  final _oobController = TextEditingController();
  bool _isOobVerified = false;

  MobileScannerController cameraController = MobileScannerController();
  bool _isCameraActive = false;

  @override
  void dispose() {
    cameraController.dispose();
    _codeController.dispose();
    _amountController.dispose();
    _pinController.dispose();
    _oobController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String code = barcodes.first.rawValue!;
      // Stop scanning once detected to confirm it worked
      cameraController.stop();
      setState(() {
        _merchantCode = code;
        _codeController.text = _merchantCode;
        _isCameraActive = false;
        _step = 2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          if (_step == 1) _buildMerchantStep(),
          if (_step == 2) _buildAmountStep(),
          if (_step == 3) _buildReviewStep(),
          if (_step == 4) _buildPinStep(),
          const SizedBox(height: 24),
          _buildButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title = 'Scan to Pay';
    if (_step == 2) title = 'Enter Amount';
    if (_step == 3) title = 'Confirm Payment';
    if (_step == 4) title = 'Enter PIN';

    return Row(
      children: [
        if (_step > 1 || _isCameraActive)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_isCameraActive) {
                setState(() => _isCameraActive = false);
              } else {
                setState(() => _step--);
              }
            },
          ),
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildMerchantStep() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() => _isCameraActive = true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Accessing Camera...'),
                  duration: Duration(seconds: 1)),
            );
          },
          child: Container(
            height: 200,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Theme.of(context).colorScheme.primary, width: 2),
            ),
            child: _isCameraActive
                ? Stack(
                    children: [
                      MobileScanner(
                        controller: cameraController,
                        onDetect: _onDetect,
                        errorBuilder: (context, error, child) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 48),
                                const SizedBox(height: 8),
                                Text('Camera error: ${error.errorCode}',
                                    style:
                                        const TextStyle(color: Colors.white)),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _isCameraActive = false),
                                  child: const Text('Retry'),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.white, size: 8),
                              SizedBox(width: 4),
                              Text('Active',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withAlpha(128)),
                      const SizedBox(height: 12),
                      const Text('Tap to activate scanner',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR', style: TextStyle(color: Colors.grey))),
              Expanded(child: Divider()),
            ],
          ),
        ),
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            labelText: 'Enter Merchant Code',
            hintText: 'e.g. 123456',
            prefixIcon: Icon(Icons.numbers),
          ),
          keyboardType: TextInputType.number,
          onChanged: (val) => setState(() => _merchantCode = val),
        ),
      ],
    );
  }

  Widget _buildAmountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Paying Merchant: #$_merchantCode',
            style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 16),
        const Text('Amount to pay',
            style: TextStyle(fontWeight: FontWeight.w500)),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: '0.00',
            prefixText: '${widget.currencySymbol} ',
            border: InputBorder.none,
            fillColor: Colors.transparent,
          ),
          onChanged: (val) =>
              setState(() => _amount = double.tryParse(val) ?? 0),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      children: [
        _QuoteRow('Merchant ID', '#$_merchantCode'),
        _QuoteRow('Amount', widget.money.format(_amount)),
        _QuoteRow('Fee', '${widget.currencySymbol}0.00'),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.verified_user, color: Colors.green, size: 16),
            SizedBox(width: 8),
            Text('Authorized Merchant Payment',
                style: TextStyle(color: Colors.green, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildButton() {
    bool canProceed = false;
    if (_step == 1) canProceed = _merchantCode.length >= 4;
    if (_step == 2) canProceed = _amount > 0;
    if (_step == 3) canProceed = true;
    if (_step == 4) return const SizedBox.shrink();

    if (_step == 1) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: !canProceed ? null : () => setState(() => _step = 2),
              child: const Text('Next'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: widget.onReversalRequest,
            icon: const Icon(Icons.history_outlined, size: 16),
            label: const Text('Reverse a wrong payment'),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16)),
        onPressed: !canProceed
            ? null
            : () {
                if (_step < 3) {
                  setState(() => _step++);
                } else {
                  setState(() => _step = 4);
                }
              },
        child: Text(_step == 3 ? 'Confirm & Pay' : 'Next'),
      ),
    );
  }

  Widget _buildPinStep() {
    final authService = context.read<AuthService>();
    return Column(
      children: [
        _OobVerificationPanel(
          controller: _oobController,
          isVerified: _isOobVerified,
          transactionSummary:
              'Verify merchant payment of ${widget.money.format(_amount)} to #$_merchantCode before authorizing.',
          onVerifiedChanged: (value) => setState(() => _isOobVerified = value),
        ),
        const SizedBox(height: 16),
        const Text('Confirm your merchant payment with your 4-digit PIN'),
        const SizedBox(height: 24),
        Pinput(
          length: 4,
          obscureText: true,
          controller: _pinController,
          onCompleted: (pin) async {
            if (!_requireOobVerification(
                context, _pinController, _isOobVerified)) {
              return;
            }
            if (authService.verifyPin(pin)) {
              try {
                await authService.updateBalance(-_amount);
                if (!mounted) return;
                authService.logTransaction(
                    TransactionType.pay, _amount, _merchantCode);
                _handleSuccess();
              } catch (e) {
                _pinController.clear();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString()), backgroundColor: Colors.red));
                // Add notification to _HomeScreenState
                final homeState =
                    context.findAncestorStateOfType<_HomeScreenState>();
                if (homeState != null) {
                  homeState._addNotification(
                      'Transaction Failed', e.toString());
                }
                Navigator.pop(context);
              }
            } else {
              _pinController.clear();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Invalid PIN. Transaction failed.'),
                  backgroundColor: Colors.red));
              Navigator.pop(context);
            }
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _handleSuccess() {
    if (!mounted) return;
    Navigator.pop(context);
    widget.onComplete(widget.money.format(_amount), _merchantCode);
    showDialog(
      context: context,
      builder: (context) => _SuccessDialog(
        message:
            'You have successfully paid ${widget.money.format(_amount)} to merchant #$_merchantCode.',
      ),
    );
  }
}

class _SecureReversalFlow extends StatefulWidget {
  final TransactionType type;
  final String currencySymbol;
  final Function(String, String) onComplete;

  const _SecureReversalFlow({
    required this.type,
    required this.currencySymbol,
    required this.onComplete,
  });

  @override
  State<_SecureReversalFlow> createState() => _SecureReversalFlowState();
}

class _SecureReversalFlowState extends State<_SecureReversalFlow> {
  int _step = 1; // 1: Input ID, 2: PIN
  final _idController = TextEditingController();
  final _pinController = TextEditingController();
  final _oobController = TextEditingController();
  bool _isOobVerified = false;
  TransactionRecord? _foundTransaction;

  @override
  void dispose() {
    _idController.dispose();
    _pinController.dispose();
    _oobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          if (_step == 1) _buildIdStep(),
          if (_step == 2) _buildPinStep(),
          const SizedBox(height: 24),
          if (_step == 1) _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title = 'Request Reversal';
    if (_step == 2) title = 'Authorize Reversal';

    return Row(
      children: [
        if (_step > 1)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _step = 1),
          ),
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildIdStep() {
    String label = 'Destination Account Number';
    if (widget.type == TransactionType.pay) label = 'Merchant Code';
    if (widget.type == TransactionType.withdraw) label = 'Account/Phone Number';

    return Column(
      children: [
        const Text(
            'To reverse, please provide the details of the transaction you made by mistake.'),
        const SizedBox(height: 16),
        TextField(
          controller: _idController,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.search),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        const Text(
            'Note: Reversals are only possible within 5 minutes of transaction.',
            style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildPinStep() {
    final authService = context.read<AuthService>();
    return Column(
      children: [
        Text(
            'Reversing ${widget.currencySymbol} ${_foundTransaction!.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        Text('Destination: ${_foundTransaction!.destination}'),
        const SizedBox(height: 24),
        _OobVerificationPanel(
          controller: _oobController,
          isVerified: _isOobVerified,
          transactionSummary:
              'Verify reversal of ${widget.currencySymbol} ${_foundTransaction!.amount.toStringAsFixed(2)} for ${_foundTransaction!.destination}.',
          onVerifiedChanged: (value) => setState(() => _isOobVerified = value),
        ),
        const SizedBox(height: 16),
        const Text('Enter your 4-digit PIN to confirm reversal'),
        const SizedBox(height: 16),
        Pinput(
          length: 4,
          obscureText: true,
          controller: _pinController,
          onCompleted: (pin) async {
            if (!_requireOobVerification(
                context, _pinController, _isOobVerified)) {
              return;
            }
            if (authService.verifyPin(pin)) {
              await authService.reverseTransaction(_foundTransaction!);
              if (!mounted) return;
              Navigator.pop(context);
              widget.onComplete('Reversal Successful',
                  'USh ${(_foundTransaction!.amount).toStringAsFixed(2)} has been refunded to your wallet.');
              _showReversalSuccessDialog();
            } else {
              _pinController.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Invalid PIN. Reversal failed.'),
                    backgroundColor: Colors.red),
              );
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _findAndValidateTransaction,
        child: const Text('Find Transaction'),
      ),
    );
  }

  void _findAndValidateTransaction() {
    final authService = context.read<AuthService>();
    final destination = _idController.text.trim();

    try {
      // Find the most recent transaction matching destination and type
      final tx = authService.recentTransactions.firstWhere(
        (t) =>
            t.destination == destination &&
            t.type == widget.type &&
            !t.isReversed,
      );

      if (authService.canReverse(tx)) {
        setState(() {
          _foundTransaction = tx;
          _step = 2;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Reversal expired (over 5 mins) or already reversed.'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No matching transaction found.'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showReversalSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => const _SuccessDialog(
        message:
            'The transaction has been reversed. Your balance has been updated.',
      ),
    );
  }
}

class _HighValueTransferFlow extends StatefulWidget {
  const _HighValueTransferFlow({
    required this.money,
    required this.currencySymbol,
    required this.onComplete,
  });

  final NumberFormat money;
  final String currencySymbol;
  final Future<void> Function(double amount, String destination, String purpose)
      onComplete;

  @override
  State<_HighValueTransferFlow> createState() => _HighValueTransferFlowState();
}

class _HighValueTransferFlowState extends State<_HighValueTransferFlow> {
  static const double _minimumAmount = 5000000;

  int _step = 1;
  final _amountController = TextEditingController();
  final _destinationController = TextEditingController();
  final _purposeController = TextEditingController();
  final _mfaController = TextEditingController();
  final _pinController = TextEditingController();
  final _oobController = TextEditingController();
  double _amount = 0;
  bool _sourceOfFundsConfirmed = false;
  bool _beneficiaryConfirmed = false;
  bool _isOobVerified = false;
  bool _isSubmitting = false;

  bool get _hasTransferDetails =>
      _amount >= _minimumAmount &&
      _destinationController.text.trim().length >= 4 &&
      _purposeController.text.trim().length >= 6;

  bool get _amlConfirmed =>
      _sourceOfFundsConfirmed && _beneficiaryConfirmed && _hasTransferDetails;

  @override
  void dispose() {
    _amountController.dispose();
    _destinationController.dispose();
    _purposeController.dispose();
    _mfaController.dispose();
    _pinController.dispose();
    _oobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildSecurityBanner(),
            const SizedBox(height: 20),
            if (_step == 1) _buildTransferDetailsStep(),
            if (_step == 2) _buildAmlStep(),
            if (_step == 3) _buildAuthenticationStep(),
            const SizedBox(height: 22),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = switch (_step) {
      2 => 'AML Review',
      3 => 'High Security Auth',
      _ => 'Big Money Transfer',
    };

    return Row(
      children: [
        if (_step > 1)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _isSubmitting ? null : () => setState(() => _step--),
          ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildSecurityBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _appOutline),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.enhanced_encryption_outlined, color: _appPrimary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Secured for large transfers',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Requires MFA, transaction PIN, end-to-end encryption, and strict AML checks before release.',
            style: TextStyle(color: _appTextMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Transfer amount',
            helperText:
                'Minimum: ${widget.money.format(_minimumAmount)} for this secure route',
            prefixText: '${widget.currencySymbol} ',
            prefixIcon: const Icon(Icons.payments_outlined),
          ),
          onChanged: (value) => setState(() {
            _amount = double.tryParse(value.replaceAll(',', '')) ?? 0;
          }),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _destinationController,
          decoration: const InputDecoration(
            labelText: 'Beneficiary account or reference',
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _purposeController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Transfer purpose',
            hintText: 'e.g. Property purchase, supplier payment',
            prefixIcon: Icon(Icons.description_outlined),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildAmlStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuoteRow('Amount', widget.money.format(_amount)),
        _QuoteRow('Beneficiary', _destinationController.text.trim()),
        _QuoteRow('Purpose', _purposeController.text.trim()),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _sourceOfFundsConfirmed,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Source of funds verified'),
          subtitle: const Text(
            'I confirm supporting documents are ready for compliance review.',
          ),
          onChanged: (value) =>
              setState(() => _sourceOfFundsConfirmed = value ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _beneficiaryConfirmed,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Beneficiary and AML screening confirmed'),
          subtitle: const Text(
            'The beneficiary is known and the transfer has a lawful purpose.',
          ),
          onChanged: (value) =>
              setState(() => _beneficiaryConfirmed = value ?? false),
        ),
      ],
    );
  }

  Widget _buildAuthenticationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter the 6-digit MFA code',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Pinput(
          length: 6,
          controller: _mfaController,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        _OobVerificationPanel(
          controller: _oobController,
          isVerified: _isOobVerified,
          transactionSummary:
              'Verify high-value transfer of ${widget.money.format(_amount)} to ${_destinationController.text.trim()} before MFA and PIN release.',
          onVerifiedChanged: (value) => setState(() => _isOobVerified = value),
        ),
        const SizedBox(height: 20),
        const Text(
          'Confirm with your transaction PIN',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Pinput(
          length: 4,
          obscureText: true,
          controller: _pinController,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: _appPrimary, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'End-to-end encryption is enabled for beneficiary, amount, purpose, and compliance documents.',
                style: TextStyle(color: _appTextMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    final enabled = switch (_step) {
      1 => _hasTransferDetails,
      2 => _amlConfirmed,
      3 => !_isSubmitting &&
          _isOobVerified &&
          _mfaController.text.length == 6 &&
          _pinController.text.length == 4,
      _ => false,
    };

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: enabled ? _handleAction : null,
        icon: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.verified_user_outlined),
        label: Text(_step == 3 ? 'Authorize Secure Transfer' : 'Continue'),
      ),
    );
  }

  Future<void> _handleAction() async {
    if (_step < 3) {
      setState(() => _step++);
      return;
    }

    final authService = context.read<AuthService>();
    if (!_requireOobVerification(context, _pinController, _isOobVerified)) {
      return;
    }
    if (!authService.verifyPin(_pinController.text)) {
      _pinController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid transaction PIN. Transfer stopped.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {});
      return;
    }

    setState(() => _isSubmitting = true);
    await widget.onComplete(
      _amount,
      _destinationController.text.trim(),
      _purposeController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
  }
}

class _TopupSource {
  const _TopupSource({
    required this.label,
    required this.description,
    required this.icon,
    required this.isMobileWallet,
  });

  final String label;
  final String description;
  final IconData icon;
  final bool isMobileWallet;
}

class _SecureTopupFlow extends StatefulWidget {
  const _SecureTopupFlow({
    required this.money,
    required this.currencySymbol,
    required this.homeCountry,
    required this.onComplete,
  });

  final NumberFormat money;
  final String currencySymbol;
  final String? homeCountry;
  final Function(String, String) onComplete;

  @override
  State<_SecureTopupFlow> createState() => _SecureTopupFlowState();
}

class _SecureTopupFlowState extends State<_SecureTopupFlow> {
  int _step = 1; // 1: Source, 2: Account, 3: Amount, 4: Review, 5: PIN
  late PaymentCountry _selectedCountry;
  late _TopupSource _selectedSource;
  String _accountReference = '';
  double _amount = 0;
  final _accountController = TextEditingController();
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();
  final _oobController = TextEditingController();
  bool _isOobVerified = false;

  @override
  void initState() {
    super.initState();
    _selectedCountry =
        PaymentRegionService.countryByName(widget.homeCountry ?? '') ??
            PaymentRegionService.countries.firstWhere(
              (country) => country.name == 'United States',
              orElse: () => PaymentRegionService.countries.first,
            );
    _selectedSource = _sourcesFor(_selectedCountry).first;
  }

  @override
  void dispose() {
    _accountController.dispose();
    _amountController.dispose();
    _pinController.dispose();
    _oobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            if (_step == 1) _buildSourceStep(),
            if (_step == 2) _buildAccountStep(),
            if (_step == 3) _buildAmountStep(),
            if (_step == 4) _buildReviewStep(),
            if (_step == 5) _buildPinStep(),
            const SizedBox(height: 24),
            _buildButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = 'Top Up';
    if (_step == 2) title = 'Account Details';
    if (_step == 3) title = 'Enter Amount';
    if (_step == 4) title = 'Review Topup';
    if (_step == 5) {
      title = _selectedSource.isMobileWallet ? 'SIM Account PIN' : 'Bank PIN';
    }

    return Row(
      children: [
        if (_step > 1)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _step--),
          ),
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildSourceStep() {
    final countries = PaymentRegionService.countries.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final sources = _sourcesFor(_selectedCountry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose the bank or mobile SIM account to draw funds from.'),
        const SizedBox(height: 16),
        DropdownButtonFormField<PaymentCountry>(
          initialValue: _selectedCountry,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Country',
            prefixIcon: Icon(Icons.public_outlined),
          ),
          items: countries
              .map(
                (country) => DropdownMenuItem(
                  value: country,
                  child:
                      Text('${country.name} - ${country.localTransferLabel}'),
                ),
              )
              .toList(),
          onChanged: (country) {
            if (country == null) return;
            setState(() {
              _selectedCountry = country;
              _selectedSource = _sourcesFor(country).first;
              _accountReference = '';
              _accountController.clear();
            });
          },
        ),
        const SizedBox(height: 16),
        ...sources.map(
          (source) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TopupSourceTile(
              source: source,
              selected: source.label == _selectedSource.label,
              onTap: () => setState(() {
                _selectedSource = source;
                _accountReference = '';
                _accountController.clear();
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountStep() {
    final isMobile = _selectedSource.isMobileWallet;

    return Column(
      children: [
        Text(
          isMobile
              ? 'Enter the ${_selectedSource.label} mobile SIM account number.'
              : 'Enter the bank account number to draw funds from.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _accountController,
          maxLength: isMobile ? 15 : 18,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          keyboardType: TextInputType.number,
          onChanged: (val) => setState(() => _accountReference = val),
          decoration: InputDecoration(
            labelText: isMobile
                ? '${_selectedSource.label} number'
                : 'Bank account number',
            hintText: isMobile
                ? '${_selectedCountry.dialCode} mobile number'
                : 'Account number',
            prefixIcon: Icon(
              isMobile
                  ? Icons.phone_android_outlined
                  : Icons.account_balance_outlined,
            ),
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildAmountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            'Topping up from ${_selectedSource.label}: ${_maskedAccountReference()}',
            style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 16),
        const Text('Amount to draw',
            style: TextStyle(fontWeight: FontWeight.w500)),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: '0.00',
            prefixText: '${widget.currencySymbol} ',
            border: InputBorder.none,
            fillColor: Colors.transparent,
          ),
          onChanged: (val) =>
              setState(() => _amount = double.tryParse(val) ?? 0),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      children: [
        _QuoteRow('Country', _selectedCountry.name),
        _QuoteRow('From', _selectedSource.label),
        _QuoteRow('Account', _maskedAccountReference()),
        _QuoteRow('Amount', widget.money.format(_amount)),
        _QuoteRow('Fee', '${widget.currencySymbol}0.00'),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.lock, color: Colors.blue, size: 16),
            SizedBox(width: 8),
            Text('Bank-grade encryption active',
                style: TextStyle(color: Colors.blue, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildPinStep() {
    return Column(
      children: [
        _OobVerificationPanel(
          controller: _oobController,
          isVerified: _isOobVerified,
          transactionSummary:
              'Verify topup of ${widget.money.format(_amount)} from ${_selectedSource.label}: ${_maskedAccountReference()}.',
          onVerifiedChanged: (value) => setState(() => _isOobVerified = value),
        ),
        const SizedBox(height: 16),
        Text(
          _selectedSource.isMobileWallet
              ? 'Enter your ${_selectedSource.label} mobile SIM account PIN to authorize'
              : 'Enter your bank account PIN to authorize',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Pinput(
          length: 4,
          obscureText: true,
          controller: _pinController,
          onCompleted: (pin) {
            if (!_requireOobVerification(
                context, _pinController, _isOobVerified)) {
              return;
            }
            _handleSuccess();
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildButton() {
    bool canProceed = false;
    if (_step == 1) canProceed = true;
    if (_step == 2) canProceed = _accountReference.length >= 7;
    if (_step == 3) canProceed = _amount > 0;
    if (_step == 4) canProceed = true;
    if (_step == 5) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16)),
        onPressed: !canProceed
            ? null
            : () {
                if (_step < 5) {
                  setState(() => _step++);
                }
              },
        child: Text(_step == 4 ? 'Confirm & Go to PIN' : 'Next'),
      ),
    );
  }

  void _handleSuccess() {
    Navigator.pop(context);
    widget.onComplete(widget.money.format(_amount), _sourceSummary());
  }

  List<_TopupSource> _sourcesFor(PaymentCountry country) {
    return [
      _TopupSource(
        label: 'Bank account',
        description: 'Draw funds from a linked bank account',
        icon: Icons.account_balance_outlined,
        isMobileWallet: false,
      ),
      ...country.localTransferAgents
          .where((agent) => agent.toLowerCase() != 'bank transfer')
          .map(
            (agent) => _TopupSource(
              label: agent,
              description: 'Mobile SIM wallet in ${country.name}',
              icon: Icons.sim_card_outlined,
              isMobileWallet: true,
            ),
          ),
    ];
  }

  String _maskedAccountReference() {
    if (_accountReference.length <= 4) return _accountReference;
    return 'ending ${_accountReference.substring(_accountReference.length - 4)}';
  }

  String _sourceSummary() {
    return '${_selectedSource.label} ${_maskedAccountReference()}'
        ' (${_selectedCountry.name})';
  }
}

class _TopupSourceTile extends StatelessWidget {
  const _TopupSourceTile({
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final _TopupSource source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE4F0E8) : const Color(0xFFF6F8FB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? primary : const Color(0xFFD6DEE8),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(source.icon, color: primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.label,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                    source.description,
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

class _FailureDialog extends StatelessWidget {
  const _FailureDialog({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cancel, color: Colors.red, size: 80),
          const SizedBox(height: 16),
          const Text('Failed!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context),
              child: const Text('Try Again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          const SizedBox(height: 16),
          const Text('Success!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MandatoryChangePinSheet extends StatefulWidget {
  final bool isMandatory;
  final Function(String, String) onComplete;
  const _MandatoryChangePinSheet(
      {required this.onComplete, this.isMandatory = true});

  @override
  State<_MandatoryChangePinSheet> createState() =>
      _MandatoryChangePinSheetState();
}

class _MandatoryChangePinSheetState extends State<_MandatoryChangePinSheet> {
  int _step = 1; // 1: Old PIN, 2: New PIN, 3: Confirm PIN
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  String _newPin = '';

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 20,
          right: 20),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          if (_step == 1) _buildOldPinStep(),
          if (_step == 2) _buildNewPinStep(),
          if (_step == 3) _buildConfirmPinStep(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title = 'Change Transaction PIN';
    if (widget.isMandatory && _step == 1) title = 'Set Up Security PIN';

    return Row(
      children: [
        if (_step > 1)
          IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _step--)),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (!widget.isMandatory)
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildOldPinStep() {
    final authService = context.read<AuthService>();
    return Column(
      children: [
        const Text('Enter your current 4-digit PIN'),
        const SizedBox(height: 16),
        Pinput(
          length: 4,
          obscureText: true,
          controller: _oldPinController,
          onCompleted: (pin) {
            if (authService.verifyPin(pin)) {
              setState(() => _step = 2);
            } else {
              _oldPinController.clear();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Incorrect current PIN'),
                  backgroundColor: Colors.red));
            }
          },
        ),
        if (widget.isMandatory) ...[
          const SizedBox(height: 12),
          const Text('Default PIN is 0000',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]
      ],
    );
  }

  Widget _buildNewPinStep() {
    return Column(
      children: [
        const Text('Enter your new 4-digit PIN'),
        const SizedBox(height: 16),
        Pinput(
          length: 4,
          obscureText: true,
          controller: _newPinController,
          onCompleted: (pin) {
            _newPin = pin;
            setState(() => _step = 3);
          },
        ),
      ],
    );
  }

  Widget _buildConfirmPinStep() {
    return Column(
      children: [
        const Text('Confirm your new 4-digit PIN'),
        const SizedBox(height: 16),
        Pinput(
          length: 4,
          obscureText: true,
          controller: _confirmPinController,
          onCompleted: (pin) async {
            if (pin == _newPin) {
              final authService = context.read<AuthService>();

              await authService.changePin(pin);
              widget.onComplete('Security Update',
                  'Your transaction PIN has been successfully updated.');

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('PIN updated successfully'),
                    backgroundColor: Colors.green));
              }
            } else {
              _confirmPinController.clear();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('PINs do not match'),
                  backgroundColor: Colors.red));
            }
          },
        ),
      ],
    );
  }
}
