import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

enum RateAdvice { transferNow, wait, neutral }

class ExchangeRateSnapshot {
  const ExchangeRateSnapshot({
    required this.country,
    required this.currency,
    required this.baselineRate,
    required this.currentRate,
    required this.previousRate,
    required this.updatedAt,
  });

  final String country;
  final String currency;
  final double baselineRate;
  final double currentRate;
  final double previousRate;
  final DateTime updatedAt;

  double get changeFromPrevious =>
      previousRate == 0 ? 0 : (currentRate - previousRate) / previousRate;

  double get changeFromBaseline =>
      baselineRate == 0 ? 0 : (currentRate - baselineRate) / baselineRate;

  RateAdvice get advice {
    if (changeFromBaseline <= -0.015) return RateAdvice.transferNow;
    if (changeFromBaseline >= 0.015) return RateAdvice.wait;
    return RateAdvice.neutral;
  }

  String get formattedRate => currentRate.toStringAsFixed(
        currentRate >= 100 ? 2 : 4,
      );
}

class ExchangeRateAlert {
  const ExchangeRateAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.country,
    required this.currency,
    required this.advice,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final String country;
  final String currency;
  final RateAdvice advice;
  final DateTime createdAt;
}

class ExchangeRateAlertService extends ChangeNotifier {
  final Map<String, ExchangeRateSnapshot> _rates = {};
  final List<ExchangeRateAlert> _alerts = [];
  final Random _random = Random();
  Timer? _timer;
  bool _isMonitoring = false;

  List<ExchangeRateSnapshot> get rates => List.unmodifiable(_rates.values);
  List<ExchangeRateAlert> get alerts => List.unmodifiable(_alerts);
  ExchangeRateAlert? get latestAlert => _alerts.isEmpty ? null : _alerts.first;
  bool get isMonitoring => _isMonitoring;

  void startMonitoring(Iterable<ExchangeRateSnapshot> initialRates) {
    if (_rates.isEmpty) {
      for (final rate in initialRates) {
        _rates[rate.country] = rate;
      }
    }

    if (_isMonitoring) return;
    _isMonitoring = true;
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => refreshRates());
    Future.microtask(refreshRates);
  }

  ExchangeRateSnapshot? rateForCountry(String country) => _rates[country];

  void refreshRates() {
    if (_rates.isEmpty) return;

    final updatedRates = <String, ExchangeRateSnapshot>{};
    for (final entry in _rates.entries) {
      final current = entry.value;
      final movement = (_random.nextDouble() - 0.46) * 0.018;
      final nextRate = max(0.01, current.currentRate * (1 + movement));
      final updated = ExchangeRateSnapshot(
        country: current.country,
        currency: current.currency,
        baselineRate: current.baselineRate,
        currentRate: nextRate,
        previousRate: current.currentRate,
        updatedAt: DateTime.now(),
      );
      updatedRates[entry.key] = updated;

      if (updated.changeFromPrevious.abs() >= 0.004) {
        _alerts.insert(0, _buildAlert(updated));
      }
    }

    _rates
      ..clear()
      ..addAll(updatedRates);

    if (_alerts.length > 20) {
      _alerts.removeRange(20, _alerts.length);
    }

    notifyListeners();
  }

  ExchangeRateAlert _buildAlert(ExchangeRateSnapshot rate) {
    final direction = rate.changeFromPrevious >= 0 ? 'rose' : 'dropped';
    final change = (rate.changeFromPrevious.abs() * 100).toStringAsFixed(2);
    final advice = rate.advice;
    final title = switch (advice) {
      RateAdvice.transferNow => 'Good transfer window',
      RateAdvice.wait => 'Rate is high, consider waiting',
      RateAdvice.neutral => 'Exchange rate changed',
    };
    final recommendation = switch (advice) {
      RateAdvice.transferNow =>
        'The rate is low now. This is a better time to transfer.',
      RateAdvice.wait =>
        'The rate is high now. Wait if the transfer is not urgent.',
      RateAdvice.neutral =>
        'The change is small. Transfer timing is acceptable.',
    };

    return ExchangeRateAlert(
      id: '${rate.country}-${rate.updatedAt.microsecondsSinceEpoch}',
      title: title,
      message: '${rate.country} $rate.currency rate $direction by $change%. '
          '1 USD = ${rate.formattedRate} ${rate.currency}. $recommendation',
      country: rate.country,
      currency: rate.currency,
      advice: advice,
      createdAt: rate.updatedAt,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
