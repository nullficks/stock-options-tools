import 'dart:collection';
import 'dart:math';

import 'assets.dart';
import 'markets.dart';

sealed class Oracle {
  Market marketFor({required Asset asset, required Stock money});

  Line markToMarket(
          {required Position position,
          required Stock money,
          double slippage = 0.5}) =>
      Position.mergeAll(position.decompose().map((line) =>
          marketFor(asset: line.asset, money: money).sell(slippage) *
          line.size)).singleton(money);

  Line intrinsicValue({required Position position, required Stock money}) =>
      Position.mergeAll(position
              .decompose()
              .map((line) => switch (line) {
                    Line(asset: Stock()) => line,
                    Line(
                      asset: StockOption(
                        underlying: final underlying,
                        strike: final strike,
                        isPut: final isPut,
                        contractLot: final lot
                      ),
                      size: final size
                    ) =>
                      money.pos(size *
                          lot *
                          max(
                              0,
                              (isPut ? 1 : -1) *
                                  (strike -
                                      marketFor(
                                              asset: underlying,
                                              money: money)
                                          .midPrice))),
                    _ => throw AssertionError(
                        "Unexpected asset from decompose(): ${line.asset}"),
                  })
              .map((line) => markToMarket(position: line, money: money)))
          .singleton(money);

  Line extrinsicValue({required Position position, required Stock money}) =>
      (markToMarket(position: position, money: money) -
              intrinsicValue(position: position, money: money))
          .singleton(money);

  static ArchOracle fromMarkets(Iterable<Market> markets) =>
      _RealMarketsOracle(markets);
}

abstract class ArchOracle extends Oracle {
  Iterable<Market> get allMarkets;
}

class _RealMarketsOracle extends ArchOracle {
  @override
  final Iterable<Market> allMarkets;

  final Map<Asset, Map<Asset, Market>> _markets = HashMap();
  final Map<(Asset, Asset), Market> _cache = HashMap();

  _RealMarketsOracle(this.allMarkets) {
    for (final market in allMarkets) {
      for (final m in [market, market.reverse]) {
        (_markets[m.asset] ??= HashMap())[m.money] = m;
      }
    }
  }

  @override
  Market marketFor({required Asset asset, required Stock money}) {
    final cachedResult = _cache[(asset, money)];
    if (cachedResult != null) {
      return cachedResult;
    }
    Set<Asset> visitedAssets = HashSet();
    SplayTreeSet<Market> candidateMarkets = SplayTreeSet((Market a, Market b) {
      int comparison = a.relativeSpread.compareTo(b.relativeSpread);
      if (comparison != 0) return comparison;
      comparison = a.asset.name.compareTo(b.asset.name);
      if (comparison != 0) return comparison;
      return a.money.name.compareTo(b.money.name);
    });
    candidateMarkets.add(Market.createIdentity(asset));
    while (candidateMarkets.isNotEmpty) {
      final visitingMarket = candidateMarkets.first;
      candidateMarkets.remove(visitingMarket);
      if (visitingMarket.money == money) {
        _cache[(asset, money)] = visitingMarket;
        return visitingMarket;
      }
      visitedAssets.add(visitingMarket.money);

      final Map<Asset, Market>? nextMarkets = _markets[visitingMarket.money];
      if (nextMarkets != null) {
        for (final entry in nextMarkets.entries) {
          final maybeCandidateMarket = entry.value;
          if (!visitedAssets.contains(maybeCandidateMarket.money)) {
            candidateMarkets.add(visitingMarket.concatenate(entry.value));
          }
        }
      }
    }
    throw ArgumentError("Can't create a market from $asset to $money");
  }
}

class SimulatedOracle extends Oracle {
  final Map<(Asset, Stock), double> _prices = HashMap();

  @override
  Market marketFor({required Asset asset, required Stock money}) {
    if (asset == money) {
      return Market.createIdentity(asset);
    }
    final price = _prices[(asset, money)];
    if (price == null) {
      throw StateError("Price was requested for asset $asset and "
          "money $money but no such price was configured via setPrice(). "
          "Known prices: $_prices");
    }
    return Market.create(
        asset: asset, money: money, bidPrice: price, askPrice: price);
  }

  void setPrice(
      {required Asset asset, required Stock money, required double price}) {
    _prices[(asset, money)] = price;
  }
}
