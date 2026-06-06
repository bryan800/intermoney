import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../services/auth_service.dart';
import '../services/live_chat_service.dart';
import 'login_screen.dart';

const Color _adminBackground = Color(0xFFF2F3F5);
const Color _adminSurface = Color(0xFFFAFEFB);
const Color _adminPrimary = Color(0xFF0E7A5F);
const Color _adminSecondary = Color(0xFF0F9AA7);
const Color _adminWarning = Color(0xFFF4B740);
const Color _adminMuted = Color(0xFF60766B);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _selectedStatus = 'All';
  TransactionType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isAdmin) {
      return Scaffold(
        backgroundColor: _adminBackground,
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: _adminBackground,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              color: _adminSurface,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: _adminPrimary,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Admin access only',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please log in with an administrator account to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _adminMuted),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (_) => false,
                        );
                      },
                      child: const Text('Go to login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final transactions = _filteredTransactions(_allTransactions(auth));
    final totalVolume = transactions.fold<double>(
      0,
      (sum, tx) => sum + tx.amount,
    );
    final reviewCount = transactions
        .where((tx) => tx.status == 'Review' || tx.status == 'Flagged')
        .length;

    return Scaffold(
      backgroundColor: _adminBackground,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: _adminBackground,
        actions: [
          IconButton(
            tooltip: 'Live chats',
            onPressed: () => _showChatInbox(context),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: 'Registered accounts',
            onPressed: () => _showAccounts(context),
            icon: const Icon(Icons.manage_accounts_outlined),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await context.read<AuthService>().logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            return ListView(
              padding: EdgeInsets.all(isWide ? 24 : 14),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AdminHero(totalTransactions: transactions.length),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: constraints.maxWidth < 420
                              ? 1
                              : isWide
                                  ? 4
                                  : 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: isWide ? 2.6 : 1.7,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _MetricCard(
                              title: 'Transactions',
                              value: transactions.length.toString(),
                              icon: Icons.receipt_long_outlined,
                              color: _adminPrimary,
                            ),
                            _MetricCard(
                              title: 'Volume',
                              value: NumberFormat.compact().format(totalVolume),
                              icon: Icons.account_balance_wallet_outlined,
                              color: _adminSecondary,
                            ),
                            _MetricCard(
                              title: 'Review',
                              value: reviewCount.toString(),
                              icon: Icons.policy_outlined,
                              color: _adminWarning,
                            ),
                            _MetricCard(
                              title: 'Customers',
                              value: transactions
                                  .map((tx) => tx.account)
                                  .toSet()
                                  .length
                                  .toString(),
                              icon: Icons.groups_outlined,
                              color: const Color(0xFF6D6AE8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildFilters(),
                        const SizedBox(height: 12),
                        ...transactions.map(_TransactionTile.new),
                        if (transactions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child:
                                  Text('No real user money transactions yet.'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        DropdownMenu<String>(
          initialSelection: _selectedStatus,
          label: const Text('Status'),
          width: 170,
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: 'All', label: 'All'),
            DropdownMenuEntry(value: 'Completed', label: 'Completed'),
            DropdownMenuEntry(value: 'Review', label: 'Review'),
            DropdownMenuEntry(value: 'Flagged', label: 'Flagged'),
            DropdownMenuEntry(value: 'Reversed', label: 'Reversed'),
          ],
          onSelected: (value) {
            if (value == null) return;
            setState(() => _selectedStatus = value);
          },
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<TransactionType?>(
            segments: const [
              ButtonSegment(value: null, label: Text('All')),
              ButtonSegment(value: TransactionType.send, label: Text('Send')),
              ButtonSegment(
                  value: TransactionType.withdraw, label: Text('Withdraw')),
              ButtonSegment(value: TransactionType.pay, label: Text('Pay')),
              ButtonSegment(value: TransactionType.topup, label: Text('Topup')),
            ],
            selected: {_selectedType},
            onSelectionChanged: (value) {
              setState(() => _selectedType = value.first);
            },
          ),
        ),
      ],
    );
  }

  void _showAccounts(BuildContext context) {
    final auth = context.read<AuthService>();
    final accounts = auth.registeredAccounts;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.sizeOf(context).height * 0.82,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _adminSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.manage_accounts_outlined,
                    color: _adminPrimary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Registered accounts',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: accounts.isEmpty
                  ? const Center(child: Text('No registered accounts yet.'))
                  : ListView.separated(
                      itemCount: accounts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        return _AccountTile(
                          account: account,
                          transactions: auth
                              .transactionsForAccount(account.accountNumber),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatInbox(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AdminChatInboxSheet(),
    );
  }

  List<_AdminTransaction> _allTransactions(AuthService auth) {
    final liveTransactions = auth.recentTransactions.map((tx) {
      return _AdminTransaction(
        id: 'TRX-${tx.id}',
        customer: tx.customerName,
        account: tx.accountNumber,
        country: tx.country,
        type: tx.type,
        amount: tx.amount,
        currency: tx.currency,
        destination: tx.destination,
        status: tx.isReversed ? 'Reversed' : _statusFor(tx),
        risk: _riskFor(tx.amount),
        timestamp: tx.timestamp,
      );
    });

    return [...liveTransactions]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  String _statusFor(TransactionRecord tx) {
    if (tx.amount >= 5000000) return 'Flagged';
    if (tx.amount >= 1000000 || tx.type == TransactionType.withdraw) {
      return 'Review';
    }
    return 'Completed';
  }

  String _riskFor(double amount) {
    if (amount >= 5000000) return 'High';
    if (amount >= 1000000) return 'Medium';
    return 'Low';
  }

  List<_AdminTransaction> _filteredTransactions(
    List<_AdminTransaction> transactions,
  ) {
    return transactions.where((tx) {
      final statusMatches =
          _selectedStatus == 'All' || tx.status == _selectedStatus;
      final typeMatches = _selectedType == null || tx.type == _selectedType;
      return statusMatches && typeMatches;
    }).toList();
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.transactions,
  });

  final AccountRecord account;
  final List<TransactionRecord> transactions;

  @override
  Widget build(BuildContext context) {
    final statusColor = account.isActive ? _adminPrimary : _adminMuted;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: statusColor.withAlpha(30),
        child: Icon(Icons.person_outline, color: statusColor),
      ),
      title: Text(
        account.name,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        'Account ${account.accountNumber} - ${account.country}\n'
        'Last active ${DateFormat('MMM d, y h:mm a').format(account.lastActiveAt)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _StatusPill(
            label: account.isActive ? 'Active' : 'Inactive',
            color: statusColor,
          ),
          const SizedBox(height: 4),
          Text(
            '${transactions.length} tx',
            style: const TextStyle(color: _adminMuted, fontSize: 12),
          ),
        ],
      ),
      onTap: () => _showAccountHistory(context),
    );
  }

  void _showAccountHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.sizeOf(context).height * 0.78,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _adminSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_circle_outlined, color: _adminPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Account ${account.accountNumber}',
                        style: const TextStyle(color: _adminMuted),
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
            const SizedBox(height: 8),
            _DetailRow('Email', account.email),
            _DetailRow('Country', account.country),
            _DetailRow(
              'Status',
              account.isActive ? 'Active now' : 'Inactive',
            ),
            _DetailRow(
              'Last active',
              DateFormat('MMM d, y h:mm a').format(account.lastActiveAt),
            ),
            const Divider(height: 24),
            const Text(
              'Transaction history',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: transactions.isEmpty
                  ? const Center(
                      child: Text('No transactions for this account yet.'),
                    )
                  : ListView.separated(
                      itemCount: transactions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(_iconFor(tx.type)),
                          title: Text(
                            '${tx.type.name.toUpperCase()} - ${tx.destination}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${DateFormat('MMM d, y h:mm a').format(tx.timestamp)} - ${tx.channel}',
                          ),
                          trailing: Text(
                            '${tx.currency} ${NumberFormat('#,##0.00').format(tx.amount)}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
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

  IconData _iconFor(TransactionType type) {
    return switch (type) {
      TransactionType.send => Icons.send_outlined,
      TransactionType.withdraw => Icons.account_balance_wallet_outlined,
      TransactionType.pay => Icons.storefront_outlined,
      TransactionType.topup => Icons.add_card_outlined,
    };
  }
}

class _AdminChatInboxSheet extends StatelessWidget {
  const _AdminChatInboxSheet();

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<LiveChatService>();
    final threads = chat.threads;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _adminSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline, color: _adminPrimary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Live chat inbox',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: threads.isEmpty
                ? const Center(child: Text('No customer messages yet.'))
                : ListView.separated(
                    itemCount: threads.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final thread = threads[index];
                      final latest = thread.latestMessage;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: _adminPrimary.withAlpha(30),
                          child: const Icon(Icons.person_outline,
                              color: _adminPrimary),
                        ),
                        title: Text(
                          thread.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          'Account ${thread.accountNumber}\n'
                          '${latest?.text ?? 'No messages'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: latest == null
                            ? null
                            : Text(
                                DateFormat('h:mm a').format(latest.sentAt),
                                style: const TextStyle(color: _adminMuted),
                              ),
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) =>
                              _AdminChatThreadSheet(thread: thread),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AdminChatThreadSheet extends StatefulWidget {
  const _AdminChatThreadSheet({required this.thread});

  final LiveChatThread thread;

  @override
  State<_AdminChatThreadSheet> createState() => _AdminChatThreadSheetState();
}

class _AdminChatThreadSheetState extends State<_AdminChatThreadSheet> {
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<LiveChatService>();
    final messages = chat.messagesForAccount(widget.thread.accountNumber);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _adminSurface,
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
                  child: Icon(Icons.support_agent, color: _adminPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.thread.customerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Account ${widget.thread.accountNumber}',
                        style: const TextStyle(color: _adminMuted),
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
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final fromAdmin = message.sentByAdmin;
                return Align(
                  alignment:
                      fromAdmin ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 340),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          fromAdmin ? _adminPrimary : const Color(0xFFF2F7F4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: TextStyle(
                            color: fromAdmin
                                ? Colors.white
                                : const Color(0xFF17231E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, h:mm a').format(message.sentAt),
                          style: TextStyle(
                            color: fromAdmin ? Colors.white70 : _adminMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Reply as admin',
                      prefixIcon: Icon(Icons.reply_outlined),
                    ),
                    onSubmitted: (_) => _sendReply(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send reply',
                  onPressed: _sendReply,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    _replyController.clear();
    await context.read<LiveChatService>().sendAdminReply(
          customerName: widget.thread.customerName,
          accountNumber: widget.thread.accountNumber,
          text: text,
        );
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero({required this.totalTransactions});

  final int totalTransactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_adminPrimary, _adminSecondary],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings_outlined,
              color: Colors.white, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Customer transaction monitoring',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalTransactions transactions visible for review',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _adminSurface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            Text(title, style: const TextStyle(color: _adminMuted)),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile(this.transaction);

  final _AdminTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (transaction.status) {
      'Completed' => _adminPrimary,
      'Review' => _adminWarning,
      'Flagged' => const Color(0xFFD94A3A),
      'Reversed' => const Color(0xFF6D6AE8),
      _ => _adminMuted,
    };
    final typeIcon = switch (transaction.type) {
      TransactionType.send => Icons.send_outlined,
      TransactionType.withdraw => Icons.account_balance_wallet_outlined,
      TransactionType.pay => Icons.storefront_outlined,
      TransactionType.topup => Icons.add_card_outlined,
    };

    return Card(
      color: _adminSurface,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(30),
          child: Icon(typeIcon, color: statusColor),
        ),
        title: Text(
          transaction.customer,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${transaction.id} • ${transaction.country} • ${transaction.destination}\n'
          '${DateFormat('MMM d, h:mm a').format(transaction.timestamp)}',
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${transaction.currency} ${NumberFormat.compact().format(transaction.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 4),
              _StatusPill(label: transaction.status, color: statusColor),
            ],
          ),
        ),
        onTap: () => _showTransactionDetails(context),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _adminSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              transaction.id,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _DetailRow('Customer', transaction.customer),
            _DetailRow('Account', transaction.account),
            _DetailRow('Type', transaction.type.name.toUpperCase()),
            _DetailRow('Destination', transaction.destination),
            _DetailRow('Risk', transaction.risk),
            _DetailRow('Status', transaction.status),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: _adminMuted)),
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

class _AdminTransaction {
  const _AdminTransaction({
    required this.id,
    required this.customer,
    required this.account,
    required this.country,
    required this.type,
    required this.amount,
    required this.currency,
    required this.destination,
    required this.status,
    required this.risk,
    required this.timestamp,
  });

  final String id;
  final String customer;
  final String account;
  final String country;
  final TransactionType type;
  final double amount;
  final String currency;
  final String destination;
  final String status;
  final String risk;
  final DateTime timestamp;
}
