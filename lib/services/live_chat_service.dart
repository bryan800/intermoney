import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.threadId,
    required this.customerName,
    required this.accountNumber,
    required this.text,
    required this.sentByAdmin,
    required this.sentAt,
  });

  final String id;
  final String threadId;
  final String customerName;
  final String accountNumber;
  final String text;
  final bool sentByAdmin;
  final DateTime sentAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'threadId': threadId,
      'customerName': customerName,
      'accountNumber': accountNumber,
      'text': text,
      'sentByAdmin': sentByAdmin,
      'sentAt': sentAt.toIso8601String(),
    };
  }

  factory LiveChatMessage.fromJson(Map<String, dynamic> json) {
    return LiveChatMessage(
      id: json['id'] as String? ?? '',
      threadId: json['threadId'] as String? ?? '',
      customerName: json['customerName'] as String? ?? 'Customer',
      accountNumber: json['accountNumber'] as String? ?? 'Unknown',
      text: json['text'] as String? ?? '',
      sentByAdmin: json['sentByAdmin'] as bool? ?? false,
      sentAt:
          DateTime.tryParse(json['sentAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class LiveChatThread {
  const LiveChatThread({
    required this.threadId,
    required this.customerName,
    required this.accountNumber,
    required this.messages,
  });

  final String threadId;
  final String customerName;
  final String accountNumber;
  final List<LiveChatMessage> messages;

  LiveChatMessage? get latestMessage => messages.isEmpty ? null : messages.last;

  int get unreadForAdmin =>
      messages.where((message) => !message.sentByAdmin).length;
}

class LiveChatService with ChangeNotifier {
  static const _messagesKey = 'live_chat_messages';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final List<LiveChatMessage> _messages = [];
  bool _loaded = false;

  List<LiveChatMessage> messagesForAccount(String accountNumber) {
    _ensureLoaded();
    return _messages
        .where((message) => message.accountNumber == accountNumber)
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  List<LiveChatThread> get threads {
    _ensureLoaded();
    final grouped = <String, List<LiveChatMessage>>{};
    for (final message in _messages) {
      grouped.putIfAbsent(message.threadId, () => []).add(message);
    }

    final result = grouped.entries.map((entry) {
      final messages = entry.value
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      final latest = messages.last;
      return LiveChatThread(
        threadId: entry.key,
        customerName: latest.customerName,
        accountNumber: latest.accountNumber,
        messages: List.unmodifiable(messages),
      );
    }).toList();

    result.sort((a, b) {
      final aTime =
          a.latestMessage?.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          b.latestMessage?.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return result;
  }

  Future<void> load() async {
    if (_loaded) return;
    final stored = await _storage.read(key: _messagesKey);
    if (stored != null && stored.isNotEmpty) {
      try {
        final decoded = jsonDecode(stored) as List<dynamic>;
        _messages
          ..clear()
          ..addAll(decoded.whereType<Map>().map((json) =>
              LiveChatMessage.fromJson(Map<String, dynamic>.from(json))));
      } catch (_) {
        _messages.clear();
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> sendCustomerMessage({
    required String customerName,
    required String accountNumber,
    required String text,
  }) async {
    await _addMessage(
      customerName: customerName,
      accountNumber: accountNumber,
      text: text,
      sentByAdmin: false,
    );
  }

  Future<void> sendAdminReply({
    required String customerName,
    required String accountNumber,
    required String text,
  }) async {
    await _addMessage(
      customerName: customerName,
      accountNumber: accountNumber,
      text: text,
      sentByAdmin: true,
    );
  }

  Future<void> _addMessage({
    required String customerName,
    required String accountNumber,
    required String text,
    required bool sentByAdmin,
  }) async {
    await load();
    final now = DateTime.now();
    final cleanAccount =
        accountNumber.trim().isEmpty ? 'Unknown' : accountNumber.trim();
    _messages.add(
      LiveChatMessage(
        id: now.microsecondsSinceEpoch.toString(),
        threadId: cleanAccount,
        customerName:
            customerName.trim().isEmpty ? 'Customer' : customerName.trim(),
        accountNumber: cleanAccount,
        text: text.trim(),
        sentByAdmin: sentByAdmin,
        sentAt: now,
      ),
    );
    await _save();
    notifyListeners();
  }

  void _ensureLoaded() {
    if (!_loaded) {
      load();
    }
  }

  Future<void> _save() async {
    await _storage.write(
      key: _messagesKey,
      value: jsonEncode(_messages.map((message) => message.toJson()).toList()),
    );
  }
}
