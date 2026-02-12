import 'dart:convert';
import 'dart:js_interop';

import 'package:stock_options_tools/assets.dart';
import 'package:stock_options_tools/yahoo_finance.dart';
import 'package:stock_options_tools/markets.dart';
import 'package:stock_options_tools/strategies.dart';
import 'package:stock_options_tools/url_fetcher.dart';

@JS()
external void jsMain();

@JS()
external set fetchStockOptionsDart(JSFunction value);

@JS()
external set coveredCallsDart(JSFunction value);

@JS()
external set verticalSpreadsDart(JSFunction value);

UrlFetcher _urlFetcher = UrlFetcher(Duration(minutes: 5));

Future<List<dynamic>> fetchStockOptions(String ticker) async {
  final markets = await YahooFinance.fetchOptions(ticker.toUpperCase(), _urlFetcher);
  
  return markets.map((m) => {
    'symbol': m.asset.symbol,
    'name': m.asset.name,
    'bid': m.bidPrice,
    'ask': m.askPrice,
    'mid': m.midPrice,
  }).toList();
}

Future<String> coveredCalls(String ticker, double slippage) async {
  final stock = Stock.fromSymbol(ticker);
  final markets = await YahooFinance.fetchOptions(ticker.toUpperCase(), _urlFetcher);
  final money = Stock('USD', 'USD');
  
  return jsonEncode(CoveredCall.generateAll(markets,
          underlying: stock,
          money: money,
          slippage: slippage)
      .where((cc) => cc.breakeven != null)
      .toList());
}

Future<String> verticalSpreads(String ticker, double slippage) async {
  final stock = Stock.fromSymbol(ticker);
  final markets = await YahooFinance.fetchOptions(ticker.toUpperCase(), _urlFetcher);
  final money = Stock('USD', 'USD');
  
  return jsonEncode(VerticalSpread.generateAll(markets,
          underlying: stock,
          money: money,
          slippage: slippage)
      .toList());
}

void main() {
  fetchStockOptionsDart = (JSString ticker) {
    return fetchStockOptions(ticker.toDart)
        .then((value) => value.jsify())
        .toJS;
  }.toJS;
  
  coveredCallsDart = (JSString ticker, JSNumber slippage) {
    return coveredCalls(ticker.toDart, slippage.toDartDouble)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;
  
  verticalSpreadsDart = (JSString ticker, JSNumber slippage) {
    return verticalSpreads(ticker.toDart, slippage.toDartDouble)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;

  jsMain();
}
