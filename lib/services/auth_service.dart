import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/transaction_model.dart';

class AccountRecord {
  const AccountRecord({
    required this.name,
    required this.email,
    required this.accountNumber,
    required this.country,
    required this.createdAt,
    required this.lastActiveAt,
    required this.isActive,
  });

  final String name;
  final String email;
  final String accountNumber;
  final String country;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool isActive;

  AccountRecord copyWith({
    String? name,
    String? email,
    String? accountNumber,
    String? country,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? isActive,
  }) {
    return AccountRecord(
      name: name ?? this.name,
      email: email ?? this.email,
      accountNumber: accountNumber ?? this.accountNumber,
      country: country ?? this.country,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'accountNumber': accountNumber,
      'country': country,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory AccountRecord.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return AccountRecord(
      name: json['name'] as String? ?? 'Customer',
      email: json['email'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? 'Unknown',
      country: json['country'] as String? ?? 'Unknown',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      lastActiveAt:
          DateTime.tryParse(json['lastActiveAt'] as String? ?? '') ?? now,
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}

class AuthService with ChangeNotifier {
  static const String adminAccountNumber = '8877665544';
  static const String adminSupportNumber = adminAccountNumber;
  static const String _accountRegistryKey = 'registered_account_registry';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;
  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;
  String? _accountNumber;
  String? get accountNumber => _accountNumber;
  String? _userName;
  String? get userName => _userName;
  String? _userCountry;
  String? get userCountry => _userCountry;
  String? _transactionPin;
  String? get transactionPin => _transactionPin;
  String _identityVerificationStatus = 'not_started';
  String get identityVerificationStatus => _identityVerificationStatus;
  bool get identityVerificationSubmitted =>
      _identityVerificationStatus == 'under_review' ||
      _identityVerificationStatus == 'verified';
  double _balance = 12450.00; // Default starting balance
  double get balance => _balance;

  final List<AccountRecord> _registeredAccounts = [];
  List<AccountRecord> get registeredAccounts =>
      List.unmodifiable(_registeredAccounts);

  final List<TransactionRecord> _recentTransactions = [];
  List<TransactionRecord> get recentTransactions =>
      List.unmodifiable(_recentTransactions);

  void logTransaction(
    TransactionType type,
    double amount,
    String destination, {
    bool isOfflinePending = false,
    String channel = 'Online',
  }) {
    _recentTransactions.insert(
      0,
      TransactionRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        amount: amount,
        destination: destination,
        customerName: _userName ?? 'Unknown customer',
        accountNumber: _accountNumber ?? 'Unknown',
        country: _userCountry ?? 'Unknown',
        currency: currencyCode,
        timestamp: DateTime.now(),
        isOfflinePending: isOfflinePending,
        channel: channel,
      ),
    );
    _saveTransactions();
    _touchCurrentAccount();
    notifyListeners();
  }

  bool canReverse(TransactionRecord tx) {
    if (tx.isReversed) return false;
    final diff = DateTime.now().difference(tx.timestamp);
    return diff.inMinutes < 5;
  }

  Future<void> reverseTransaction(TransactionRecord tx) async {
    tx.isReversed = true;
    await updateBalance(tx.amount); // Refund the money
    await _saveTransactions();
    notifyListeners();
  }

  static const Map<String, Map<String, String>> countryCurrencies = {
    'Algeria': {'code': 'DZD', 'symbol': 'DA'},
    'Angola': {'code': 'AOA', 'symbol': 'Kz'},
    'Benin': {'code': 'XOF', 'symbol': 'CFA'},
    'Botswana': {'code': 'BWP', 'symbol': 'P'},
    'Burkina Faso': {'code': 'XOF', 'symbol': 'CFA'},
    'Burundi': {'code': 'BIF', 'symbol': 'FBu'},
    'Cameroon': {'code': 'XAF', 'symbol': 'FCFA'},
    'Canada': {'code': 'CAD', 'symbol': r'$'},
    'Central African Republic': {'code': 'XAF', 'symbol': 'FCFA'},
    'Chad': {'code': 'XAF', 'symbol': 'FCFA'},
    'Democratic Republic of the Congo': {'code': 'CDF', 'symbol': 'FC'},
    'Egypt': {'code': 'EGP', 'symbol': 'E£'},
    'Equatorial Guinea': {'code': 'XAF', 'symbol': 'FCFA'},
    'Gabon': {'code': 'XAF', 'symbol': 'FCFA'},
    'Gambia': {'code': 'GMD', 'symbol': 'D'},
    'Ghana': {'code': 'GHS', 'symbol': 'GH₵'},
    'Guinea': {'code': 'GNF', 'symbol': 'FG'},
    'Guinea-Bissau': {'code': 'XOF', 'symbol': 'CFA'},
    'Ivory Coast': {'code': 'XOF', 'symbol': 'CFA'},
    'Jamaica': {'code': 'JMD', 'symbol': r'J$'},
    'Kenya': {'code': 'KES', 'symbol': 'KSh'},
    'Lesotho': {'code': 'LSL', 'symbol': 'L'},
    'Liberia': {'code': 'LRD', 'symbol': r'L$'},
    'Libya': {'code': 'LYD', 'symbol': 'LD'},
    'Madagascar': {'code': 'MGA', 'symbol': 'Ar'},
    'Malawi': {'code': 'MWK', 'symbol': 'MK'},
    'Mali': {'code': 'XOF', 'symbol': 'CFA'},
    'Mauritania': {'code': 'MRU', 'symbol': 'UM'},
    'Mauritius': {'code': 'MUR', 'symbol': '₨'},
    'Mexico': {'code': 'MXN', 'symbol': r'$'},
    'Morocco': {'code': 'MAD', 'symbol': 'DH'},
    'Mozambique': {'code': 'MZN', 'symbol': 'MT'},
    'Namibia': {'code': 'NAD', 'symbol': r'N$'},
    'Niger': {'code': 'XOF', 'symbol': 'CFA'},
    'Nigeria': {'code': 'NGN', 'symbol': '₦'},
    'Rwanda': {'code': 'RWF', 'symbol': 'FRw'},
    'Senegal': {'code': 'XOF', 'symbol': 'CFA'},
    'Seychelles': {'code': 'SCR', 'symbol': '₨'},
    'Sierra Leone': {'code': 'SLL', 'symbol': 'Le'},
    'Somalia': {'code': 'SOS', 'symbol': 'S'},
    'South Africa': {'code': 'ZAR', 'symbol': 'R'},
    'South Sudan': {'code': 'SSP', 'symbol': '£'},
    'Sudan': {'code': 'SDG', 'symbol': '£'},
    'Tanzania': {'code': 'TZS', 'symbol': 'TSh'},
    'Togo': {'code': 'XOF', 'symbol': 'CFA'},
    'Tunisia': {'code': 'TND', 'symbol': 'DT'},
    'Uganda': {'code': 'UGX', 'symbol': 'USh'},
    'United States': {'code': 'USD', 'symbol': r'$'},
    'Zambia': {'code': 'ZMW', 'symbol': 'ZK'},
    'Zimbabwe': {'code': 'ZWL', 'symbol': r'$'},
  };

  String get currencySymbol =>
      countryCurrencies[_userCountry]?['symbol'] ?? r'$';
  String get currencyCode => countryCurrencies[_userCountry]?['code'] ?? 'USD';

  // Helper to get symbol for any country (used in UI if needed)
  static String getSymbolFor(String? country) =>
      countryCurrencies[country]?['symbol'] ?? r'$';

  Future<bool> createAccount({
    required String name,
    required String email,
    required String password,
    required String country,
    required String nationalIdNumber,
    required String dob,
  }) async {
    final normalizedUser = email.trim().toLowerCase();
    final newAccountNumber = _generateAccountNumber();
    final defaultPin = '0000';

    await _storage.write(key: 'user_name', value: name.trim());
    await _storage.write(key: 'user_email', value: normalizedUser);
    await _storage.write(key: 'user_login', value: normalizedUser);
    await _storage.write(key: 'user_country', value: country);
    await _storage.write(key: 'user_location_country', value: country);
    await _storage.write(key: 'account_number', value: newAccountNumber);
    await _storage.write(key: 'transaction_pin', value: defaultPin);
    await _storage.write(key: 'pin_changed', value: 'false');
    await _storage.write(key: 'identity_verification_status', value: 'pending');
    await _storage.write(key: 'identity_verification_submitted_at', value: '');
    await _storage.write(key: 'user_dob', value: dob);
    await _storage.write(
      key: 'national_id_number',
      value: nationalIdNumber.trim(),
    );
    await _storage.write(
      key: 'password_hash',
      value: _hashPassword(normalizedUser, password),
    );

    _userCountry = country;
    _userName = name.trim();
    _accountNumber = newAccountNumber;
    _transactionPin = defaultPin;
    _recentTransactions.clear();
    _balance = 0.0; // New accounts start with 0
    await _storage.write(key: 'user_balance', value: _balance.toString());
    _isAuthenticated = true;
    _pinChanged = false;
    _identityVerificationStatus = 'pending';
    await _upsertAccountRecord(
      AccountRecord(
        name: name.trim(),
        email: normalizedUser,
        accountNumber: newAccountNumber,
        country: country,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        isActive: true,
      ),
    );
    notifyListeners();
    return true;
  }

  bool _pinChanged = true;
  bool get pinChanged => _pinChanged;

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedUser = email.trim().toLowerCase();

    // Super default login
    if (normalizedUser == 'yan' && password == 'Yan123') {
      _userCountry = 'Uganda'; // Setting default for Yan
      _userName = 'Admin';
      _accountNumber = adminAccountNumber; // Dedicated admin account number
      _transactionPin = '0000'; // Admin PIN
      _pinChanged = true; // Admin PIN already "changed" or permanent
      _isAdmin = true;

      final storedBalance = await _storage.read(key: 'user_balance');
      _balance = storedBalance != null ? double.parse(storedBalance) : 12450.00;
      await _loadAdminTransactions();
      await _loadAccountRegistry();

      _isAuthenticated = true;
      notifyListeners();
      return true;
    }

    final storedEmail = await _storage.read(key: 'user_email');
    final storedName = await _storage.read(key: 'user_name');
    final storedLogin = await _storage.read(key: 'user_login');
    final storedPasswordHash = await _storage.read(key: 'password_hash');
    final storedAccountNumber = await _storage.read(key: 'account_number');
    final storedCountry = await _storage.read(key: 'user_country');
    final storedPin = await _storage.read(key: 'transaction_pin');
    final storedBalance = await _storage.read(key: 'user_balance');
    final storedPinChanged = await _storage.read(key: 'pin_changed');
    final storedIdentityStatus =
        await _storage.read(key: 'identity_verification_status');

    if (storedEmail == null || storedPasswordHash == null) {
      return false;
    }

    final savedUser = storedLogin ?? storedEmail;
    final savedName = storedName?.trim().toLowerCase();
    final userMatches =
        savedUser == normalizedUser || _nameMatches(savedName, normalizedUser);
    final passwordMatches =
        storedPasswordHash == _hashPassword(savedUser, password) ||
            storedPasswordHash == _hashPassword(normalizedUser, password);
    if (userMatches && passwordMatches) {
      _userCountry = storedCountry;
      _userName = storedName;
      _accountNumber = storedAccountNumber;
      _transactionPin = storedPin;
      _balance = storedBalance != null ? double.parse(storedBalance) : 0.0;
      _pinChanged = storedPinChanged == 'true';
      _identityVerificationStatus = storedIdentityStatus ?? 'not_started';
      _isAuthenticated = true;
      _isAdmin = false;
      await _loadTransactions();
      await _setAccountActive(
        accountNumber: storedAccountNumber ?? 'Unknown',
        isActive: true,
      );
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<void> updateBalance(double amount) async {
    if (amount < 0 && _balance < amount.abs()) {
      throw 'Insufficient funds on your account';
    }
    _balance += amount;
    await _storage.write(key: 'user_balance', value: _balance.toString());
    await _touchCurrentAccount();
    notifyListeners();
  }

  String _generateAccountNumber() {
    // Generates a random 10-digit account number starting with '88'
    final random =
        (10000000 + (90000000 * (DateTime.now().millisecond / 1000)).toInt())
            .toString();
    return '88$random';
  }

  Future<void> logout() async {
    await _setAccountActive(
      accountNumber: _accountNumber ?? 'Unknown',
      isActive: false,
    );
    await _storage.delete(key: 'jwt_token');
    _isAuthenticated = false;
    _isAdmin = false;
    _recentTransactions.clear();
    notifyListeners();
  }

  // Example of secure storage for sensitive data
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  String _hashPassword(String email, String password) {
    final bytes = utf8.encode('$email:$password');
    return sha256.convert(bytes).toString();
  }

  Future<void> _loadTransactions() async {
    _recentTransactions.clear();
    final storedTransactions = await _storage.read(key: _transactionLogKey);
    if (storedTransactions == null || storedTransactions.isEmpty) return;

    try {
      final decoded = jsonDecode(storedTransactions) as List<dynamic>;
      _recentTransactions.addAll(decoded.whereType<Map>().map((json) =>
          TransactionRecord.fromJson(Map<String, dynamic>.from(json))));
    } catch (_) {
      _recentTransactions.clear();
    }
  }

  Future<void> _saveTransactions() async {
    await _storage.write(
      key: _transactionLogKey,
      value: jsonEncode(_recentTransactions.map((tx) => tx.toJson()).toList()),
    );
    await _saveAdminTransactions();
  }

  List<TransactionRecord> transactionsForAccount(String accountNumber) {
    return _recentTransactions
        .where((tx) => tx.accountNumber == accountNumber)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _loadAccountRegistry() async {
    final storedAccounts = await _storage.read(key: _accountRegistryKey);
    if (storedAccounts == null || storedAccounts.isEmpty) {
      _registeredAccounts.clear();
      return;
    }

    try {
      final decoded = jsonDecode(storedAccounts) as List<dynamic>;
      _registeredAccounts
        ..clear()
        ..addAll(decoded.whereType<Map>().map(
            (json) => AccountRecord.fromJson(Map<String, dynamic>.from(json))));
      _registeredAccounts
          .sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));
    } catch (_) {
      _registeredAccounts.clear();
    }
  }

  Future<void> _saveAccountRegistry() async {
    await _storage.write(
      key: _accountRegistryKey,
      value: jsonEncode(
        _registeredAccounts.map((account) => account.toJson()).toList(),
      ),
    );
  }

  Future<void> _upsertAccountRecord(AccountRecord account) async {
    await _loadAccountRegistry();
    final index = _registeredAccounts.indexWhere(
      (item) => item.accountNumber == account.accountNumber,
    );
    if (index == -1) {
      _registeredAccounts.add(account);
    } else {
      _registeredAccounts[index] = _registeredAccounts[index].copyWith(
        name: account.name,
        email: account.email,
        country: account.country,
        lastActiveAt: account.lastActiveAt,
        isActive: account.isActive,
      );
    }
    _registeredAccounts
        .sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));
    await _saveAccountRegistry();
  }

  Future<void> _setAccountActive({
    required String accountNumber,
    required bool isActive,
  }) async {
    if (accountNumber == 'Unknown' || accountNumber == adminAccountNumber) {
      return;
    }
    await _loadAccountRegistry();
    final index = _registeredAccounts
        .indexWhere((item) => item.accountNumber == accountNumber);
    if (index == -1) return;

    _registeredAccounts[index] = _registeredAccounts[index].copyWith(
      lastActiveAt: DateTime.now(),
      isActive: isActive,
    );
    _registeredAccounts
        .sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));
    await _saveAccountRegistry();
  }

  Future<void> _touchCurrentAccount() async {
    final accountNumber = _accountNumber;
    if (_isAdmin || accountNumber == null) return;
    await _setAccountActive(accountNumber: accountNumber, isActive: true);
  }

  String get _transactionLogKey {
    final owner = _accountNumber ?? _userName ?? 'unknown';
    return 'transaction_log_$owner';
  }

  Future<void> _loadAdminTransactions() async {
    final storedTransactions =
        await _storage.read(key: 'admin_transaction_log');
    if (storedTransactions == null || storedTransactions.isEmpty) {
      _recentTransactions.clear();
      return;
    }

    try {
      final decoded = jsonDecode(storedTransactions) as List<dynamic>;
      _recentTransactions
        ..clear()
        ..addAll(decoded.whereType<Map>().map((json) =>
            TransactionRecord.fromJson(Map<String, dynamic>.from(json))));
    } catch (_) {
      _recentTransactions.clear();
    }
  }

  Future<void> _saveAdminTransactions() async {
    final storedTransactions =
        await _storage.read(key: 'admin_transaction_log');
    final Map<String, TransactionRecord> transactionsById = {};

    if (storedTransactions != null && storedTransactions.isNotEmpty) {
      try {
        final decoded = jsonDecode(storedTransactions) as List<dynamic>;
        for (final json in decoded.whereType<Map>()) {
          final tx =
              TransactionRecord.fromJson(Map<String, dynamic>.from(json));
          transactionsById[tx.id] = tx;
        }
      } catch (_) {
        transactionsById.clear();
      }
    }

    for (final tx in _recentTransactions) {
      transactionsById[tx.id] = tx;
    }

    final allTransactions = transactionsById.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    await _storage.write(
      key: 'admin_transaction_log',
      value: jsonEncode(allTransactions.map((tx) => tx.toJson()).toList()),
    );
  }

  bool _nameMatches(String? savedName, String login) {
    if (savedName == null || savedName.isEmpty) return false;
    if (savedName == login) return true;
    return savedName.split(RegExp(r'\s+')).contains(login);
  }

  Future<void> changePin(String newPin) async {
    await _storage.write(key: 'transaction_pin', value: newPin);
    await _storage.write(key: 'pin_changed', value: 'true');
    _transactionPin = newPin;
    _pinChanged = true;
    notifyListeners();
  }

  Future<void> submitIdentityVerification({
    required String documentCountry,
    required String documentType,
    String? documentPhotoName,
    String? faceVideoName,
    String? documentPhotoPath,
    String? faceVideoPath,
  }) async {
    await _storage.write(
      key: 'identity_verification_status',
      value: 'under_review',
    );
    await _storage.write(
      key: 'identity_document_country',
      value: documentCountry,
    );
    await _storage.write(
      key: 'identity_document_type',
      value: documentType,
    );
    await _storage.write(
      key: 'identity_biometric_consent',
      value: 'accepted',
    );
    if (documentPhotoName != null) {
      await _storage.write(
        key: 'identity_document_photo_name',
        value: documentPhotoName,
      );
    }
    if (faceVideoName != null) {
      await _storage.write(
        key: 'identity_face_video_name',
        value: faceVideoName,
      );
    }
    if (documentPhotoPath != null) {
      await _storage.write(
        key: 'identity_document_photo_path',
        value: documentPhotoPath,
      );
    }
    if (faceVideoPath != null) {
      await _storage.write(
        key: 'identity_face_video_path',
        value: faceVideoPath,
      );
    }
    await _storage.write(
      key: 'identity_verification_submitted_at',
      value: DateTime.now().toIso8601String(),
    );
    _identityVerificationStatus = 'under_review';
    notifyListeners();
  }

  bool verifyPin(String inputPin) {
    return _transactionPin == inputPin;
  }
}
