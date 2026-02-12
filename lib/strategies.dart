import 'dart:convert';
import 'dart:collection';

import 'assets.dart';
import 'markets.dart';
import 'oracle.dart';
import 'position_analyzer.dart';

class CoveredCall {
  final Stock underlying;
  final Stock money;
  final StockOption option;
  final DateTime expiration;
  final Market spotMarket;
  final Market callMarket;

  final PositionAnalyzer analyzer;

  final Position strategy;
  final Line optionLeg;
  final Line underlyingLeg;
  final Line moneyLeg;

  final Line underlyingToBuy;
  final Line premiumToReceive;

  final double spotPrice;
  late final double? breakeven;
  late final double? breakevenAsChange;
  late final double maxYield;
  late final double maxYieldAt;
  late final double maxYieldAtChange;
  late final double yieldIfPriceUnchanged;
  late final double equivalentHolderSellPrice;
  late final double maxProfit;
  late final double? timeValue;

  Map<String, dynamic> toJson() => {
        'underlying': underlying.symbol,
        'underlyingToBuy': underlyingToBuy.size,
        'premiumToReceive': premiumToReceive.size,
        'money': money.symbol,
        'moneySize': moneyLeg.size,
        'maxProfit': maxProfit,
        'spotPrice': spotPrice,
        'call': optionLeg.asset.name,
        'callSize': optionLeg.size,
        'DTE': expiration.daysLeft,
        'breakEven': breakeven,
        'breakEvenAsChange': breakevenAsChange,
        'maxYield': maxYield,
        'maxYieldAt': maxYieldAt,
        'maxYieldAtChange': maxYieldAtChange,
        'yieldIfPriceUnchanged': yieldIfPriceUnchanged,
        'equivalentHolderSellPrice': equivalentHolderSellPrice,
        'timeValue': timeValue,
        'strike': option.strike,
      };

  @override
  String toString() => jsonEncode(this);

  CoveredCall._(this.strategy,
      {required this.spotMarket,
      required this.callMarket,
      required this.underlying,
      required this.money,
      required this.option,
      required this.expiration,
      required this.spotPrice,
      required Oracle oracle})
      : analyzer =
            PositionAnalyzer(strategy, underlying: underlying, money: money),
        moneyLeg = strategy[money],
        underlyingLeg = strategy[underlying],
        optionLeg = strategy[option],
        underlyingToBuy = spotMarket.swap(strategy[money]),
        premiumToReceive = spotMarket.swap(-callMarket.swap(strategy[option])) {
    breakeven = analyzer.breakevens.singleOrNull?.price;
    breakevenAsChange = breakeven != null ? breakeven! / spotPrice : null;
    maxYield = analyzer.maxYield;
    maxProfit = analyzer.maxProfit;
    maxYieldAt = analyzer.bestPrices.first.fromPrice;
    maxYieldAtChange = maxYieldAt / spotPrice;
    yieldIfPriceUnchanged = analyzer.yieldAt(spotPrice);
    equivalentHolderSellPrice = spotPrice * maxYield;
    timeValue = option.midPrice != null ? option.midPrice! - option.intrinsicValue : null;
  }

  static Iterable<CoveredCall> generateAll(Iterable<Market> allMarkets,
      {required Stock underlying,
      required Stock money,
      double slippage = 0.5}) sync* {
    final size = 1.0; // Standard stock option lot is 100 shares
    final oracle = Oracle.fromMarkets(allMarkets);
    final spotMarket = oracle.marketFor(asset: underlying, money: money);
    
    for (final call in allMarkets
        .whereUnderlyingIs(underlying)
        .calls
        .coercedToMoney(money, oracle)
        .sortByStrike(Order.asc)
        .sortByExpiration(Order.asc)) {
      yield CoveredCall._(
          (call.short(slippage) + spotMarket.long(slippage)) * size,
          spotMarket: spotMarket,
          callMarket: call,
          underlying: underlying,
          money: money,
          option: call.asset.toOption,
          expiration: call.asset.toExpirable.expiration,
          spotPrice: spotMarket.midPrice,
          oracle: oracle);
    }
  }
}

enum VerticalSpreadType { over, under }

class VerticalSpread {
  final Stock underlying;
  final Stock money;
  final DateTime expiration;

  final PositionAnalyzer analyzer;

  final Position strategy;
  late final Line shortLeg;
  late final Line longLeg;
  late final Line moneyLeg;
  late final VerticalSpreadType type;

  final double spotPrice;

  late final double? breakeven;
  late final double? breakevenAsChange;
  late final double maxYield;
  late final double maxYieldAt;
  late final double maxYieldAtChange;
  late final double maxRisk;
  late final double maxRiskAt;
  late final double maxRiskAtChange;
  late final double yieldIfPriceUnchanged;

  Map<String, dynamic> toJson() => {
        'underlying': underlying.symbol,
        'money': money.symbol,
        'credit': moneyLeg.size,
        'spotPrice': spotPrice,
        'shortLeg': shortLeg.asset.name,
        'longLeg': longLeg.asset.name,
        'type': type.name,
        'DTE': expiration.daysLeft,
        'breakEven': breakeven,
        'breakEvenAsChange': breakevenAsChange,
        'maxYield': maxYield,
        'maxYieldAt': maxYieldAt,
        'maxYieldAtChange': maxYieldAtChange,
        'maxRisk': maxRisk,
        'maxRiskAt': maxRiskAt,
        'maxRiskAtChange': maxRiskAtChange,
        'yieldIfPriceUnchanged': yieldIfPriceUnchanged,
      };

  VerticalSpread._(this.strategy,
      {required this.underlying,
      required this.money,
      required this.expiration,
      required this.spotPrice})
      : analyzer =
            PositionAnalyzer(strategy, underlying: underlying, money: money) {
    for (final p in strategy.decompose()) {
      if (p.asset == money) {
        moneyLeg = p;
      } else if (p.size > 0) {
        longLeg = p;
      } else if (p.size < 0) {
        shortLeg = p;
      } else {
        throw ArgumentError("Unexpected leg: $p, in ${strategy.decompose()}");
      }
    }
    type = longLeg.asset.toOption.strike > shortLeg.asset.toOption.strike
        ? VerticalSpreadType.over
        : VerticalSpreadType.under;
    breakeven = pickNearestBoundary(spotPrice, analyzer.breakevens);
    breakevenAsChange = breakeven != null ? breakeven! / spotPrice : null;
    maxYield = analyzer.maxYield;
    maxYieldAt = pickNearestBoundary(spotPrice, analyzer.bestPrices)!;
    maxYieldAtChange = maxYieldAt / spotPrice;
    maxRisk = analyzer.maxRisk;
    maxRiskAt = pickNearestBoundary(spotPrice, analyzer.worstPrices)!;
    maxRiskAtChange = maxRiskAt / spotPrice;
    yieldIfPriceUnchanged = analyzer.yieldAt(spotPrice);
  }

  static double? pickNearestBoundary(
          double target, Iterable<PriceRange> priceRanges) =>
      pickNearest(
          target,
          priceRanges.expand(
              (priceRange) => [priceRange.fromPrice, priceRange.toPrice]));

  static double? pickNearest(double target, Iterable<double> candidates) {
    final it = candidates.iterator;
    if (!it.moveNext()) {
      return null;
    }
    double candidate = it.current;
    double distance = (target - candidate).abs();
    while (it.moveNext()) {
      double newDistance = (target - it.current).abs();
      if (newDistance < distance) {
        distance = newDistance;
        candidate = it.current;
      }
    }
    return candidate;
  }

  static Iterable<VerticalSpread> generateAll(Iterable<Market> allMarkets,
      {required Stock underlying,
      required Stock money,
      double slippage = 0.5}) sync* {
    final oracle = Oracle.fromMarkets(allMarkets);
    final spotMarket = oracle.marketFor(asset: underlying, money: money);
    final spotPrice = spotMarket.midPrice;

    for (final MapEntry<DateTime,
            Map<double, ({Market? call, Market? put})>> expirationToStrike
        in allMarkets
            .whereUnderlyingIs(underlying)
            .optionsWithStrikeInMoney(money)
            .coercedToMoney(money, oracle)
            .groupByExpiration(Order.asc)
            .mapValues((ms) => ms.groupByStrike(Order.asc).mapValues((ms) =>
                (call: ms.calls.singleOrNull, put: ms.puts.singleOrNull)))
            .entries) {
      final expiration = expirationToStrike.key,
          strikeToOptions = expirationToStrike.value;
      VerticalSpread makeSpread(Position position) => VerticalSpread._(position,
          underlying: underlying,
          money: money,
          expiration: expiration,
          spotPrice: spotPrice);

      for (final (lowStrike, highStrike) in _pairUp(strikeToOptions.keys)) {
        final (call: lowCall, put: lowPut) = strikeToOptions[lowStrike]!;
        final (call: highCall, put: highPut) = strikeToOptions[highStrike]!;

        VerticalSpread? under = keepBestValidSpread([
          if (lowPut != null && highPut != null)
            makeSpread(highPut.long(slippage) + lowPut.short(slippage)),
          if (lowCall != null && highCall != null)
            makeSpread(highCall.long(slippage) + lowCall.short(slippage)),
        ]);

        VerticalSpread? over = keepBestValidSpread([
          if (lowPut != null && highPut != null)
            makeSpread(highPut.short(slippage) + lowPut.long(slippage)),
          if (lowCall != null && highCall != null)
            makeSpread(highCall.short(slippage) + lowCall.long(slippage)),
        ]);

        yield* [under, over].nonNulls;
      }
    }
  }

  static VerticalSpread? keepBestValidSpread(
          Iterable<VerticalSpread> spreads) =>
      spreads
          .where((vs) => vs.maxRisk > 0.0)
          .where((vs) => vs.maxYield > 1.0)
          .fold<VerticalSpread?>(
              null,
              (vs1, vs2) =>
                  vs1 != null && vs1.maxYield >= vs2.maxYield ? vs1 : vs2);

  static Iterable<(T, T)> _pairUp<T>(Iterable<T> iterable) sync* {
    final it = iterable.iterator;
    if (!it.moveNext()) {
      return;
    }
    T previous = it.current;
    while (it.moveNext()) {
      T current = it.current;
      yield (previous, current);
      previous = current;
    }
  }
}
