import 'dart:collection';

sealed class Asset {
  final String name;
  final String symbol;
  const Asset(this.name, this.symbol);

  Line pos(double size) => Line(this, size);
  Line get unit => Line(this, 1.0);

  bool get isStock => this is Stock;
  Stock get asStock => this as Stock;
  bool get isExpirable => this is Expirable;
  Expirable get toExpirable => this as Expirable;
  bool get isOption => this is StockOption;
  StockOption get toOption => this as StockOption;

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is Asset && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

sealed class Position {
  Position operator -() => this * -1.0;
  Position operator *(double size) => _ScaledPosition(this, size);

  Position operator +(Position that) => _MergedPosition([this, that]);
  Position operator -(Position that) => _MergedPosition([this, -that]);

  static Position mergeAll(Iterable<Position> positions) =>
      _MergedPosition(positions);

  Iterable<Line> decompose();
  Line operator [](Asset asset) =>
      decompose().firstWhere((line) => line.asset == asset);

  Line singleton([Asset? expectedAsset]) {
    Iterable<Line> lines = decompose();
    if (lines.singleOrNull == null) {
      throw StateError("Unexpected lines, expected $expectedAsset, was $lines");
    }
    Line single = lines.single;
    if (expectedAsset != null && expectedAsset != single.asset) {
      throw StateError(
          "Expected single asset: $expectedAsset, got ${single.asset}");
    }
    return single;
  }

  @override
  String toString();
}

class Line extends Position {
  final Asset asset;
  final double size;
  Line(this.asset, this.size);

  @override
  Line operator *(double size) => Line(asset, this.size * size);
  @override
  Line operator -() => this * -1.0;

  @override
  Iterable<Line> decompose() => [this];

  @override
  String toString() => '$size X $asset';
}

class _ScaledPosition extends Position {
  final Position position;
  final double scale;
  _ScaledPosition(this.position, this.scale);

  @override
  Iterable<Line> decompose() =>
      position.decompose().map((line) => line * scale);

  @override
  String toString() => '($scale X $position)';
}

class _MergedPosition extends Position {
  final Iterable<Position> positions;
  final Map<Asset, double> _assetPositions = HashMap();
  _MergedPosition(this.positions) {
    for (final line in positions.expand((pos) => pos.decompose())) {
      _assetPositions.update(
          line.asset, (previousSize) => previousSize + line.size,
          ifAbsent: () => line.size);
    }
  }

  @override
  Iterable<Line> decompose() sync* {
    for (final entry in _assetPositions.entries) {
      yield Line(entry.key, entry.value);
    }
  }

  @override
  Line operator [](Asset asset) => asset.pos(_assetPositions[asset]!);

  @override
  String toString() => 'Sum($positions)';
}

class Stock extends Asset implements Comparable<Stock> {
  static final Map<String, Stock> _cache = {};
  const Stock(super.symbol, super.name);
  factory Stock.fromSymbol(String symbol) =>
      _cache.putIfAbsent(symbol.toUpperCase(), () => Stock(symbol.toUpperCase(), symbol.toUpperCase()));

  @override
  int compareTo(Stock that) {
    return symbol.compareTo(that.symbol);
  }
}

abstract class Expirable extends Asset {
  final Stock underlying;
  final double contractLot;
  final DateTime expiration;
  final double daysToExpiration;

  Expirable(
    super.name,
    super.symbol, {
    required this.underlying,
    required this.expiration,
    required this.daysToExpiration,
    this.contractLot = 100,
  });
}

class StockOption extends Expirable {
  final double strike;
  final bool isPut;
  final bool isCall;
  final double lastPrice;
  final double? bid;
  final double? ask;
  final double? impliedVolatility;
  final double? openInterest;
  final double? volume;

  StockOption(
    super.name,
    super.symbol, {
    required super.underlying,
    required this.strike,
    required super.expiration,
    required super.daysToExpiration,
    this.isPut = false,
    this.isCall = false,
    this.lastPrice = 0.0,
    this.bid,
    this.ask,
    this.impliedVolatility,
    this.openInterest,
    this.volume,
    super.contractLot = 100,
  }) {
    if (isPut == isCall) {
      throw ArgumentError("Exactly one of these should be true: isPut: $isPut, isCall: $isCall");
    }
  }

  double? get midPrice {
    if (bid != null && ask != null) {
      return (bid! + ask!) / 2;
    }
    return lastPrice;
  }

  double get intrinsicValue {
    // Simplified intrinsic value calculation
    return 0.0; // Will be calculated based on underlying price
  }

  @override
  String toString() => '$symbol[strike=$strike]';
}
