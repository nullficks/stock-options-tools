// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'assets.dart';
import 'markets.dart';
import 'url_fetcher.dart';

class YahooFinance {
  YahooFinance._();

  static Future<List<Market>> fetchOptions(
      String ticker, UrlFetcher urlFetcher,
      {void Function(String error)? errorListener}) async {
    final errorsSink = errorListener ?? (error) {};
    
    // Fetch option chain data from Yahoo Finance
    final url = 'https://query1.finance.yahoo.com/v7/finance/options/$ticker';
    
    try {
      final responseJson = await urlFetcher.fetch(url);
      final data = json.decode(responseJson) as Map<String, dynamic>;
      
      if (data['optionChain'] == null || 
          data['optionChain']['result'] == null ||
          (data['optionChain']['result'] as List).isEmpty) {
        errorsSink('No options data available for $ticker');
        return [];
      }
      
      final result = data['optionChain']['result'][0] as Map<String, dynamic>;
      final quote = result['quote'] as Map<String, dynamic>?;
      final underlyingPrice = quote?['regularMarketPrice']?.toDouble() ?? 0.0;
      
      final expirationDates = result['expirationDates'] as List<dynamic>? ?? [];
      final options = result['options'] as List<dynamic>? ?? [];
      
      final markets = <Market>[];
      final stock = Stock.fromSymbol(ticker);
      
      // Add the underlying stock market
      if (underlyingPrice > 0 && quote != null) {
        final bid = quote['bid']?.toDouble();
        final ask = quote['ask']?.toDouble();
        if (bid != null && ask != null) {
          markets.add(Market.create(
            asset: stock,
            money: Stock('USD', 'USD'),
            bidPrice: bid,
            askPrice: ask,
          ));
        }
      }
      
      // Process option chains
      for (final optionChain in options) {
        final calls = optionChain['calls'] as List<dynamic>? ?? [];
        final puts = optionChain['puts'] as List<dynamic>? ?? [];
        
        for (final call in calls) {
          final market = _parseOption(call, stock, true, underlyingPrice, errorsSink);
          if (market != null) {
            markets.add(market);
          }
        }
        
        for (final put in puts) {
          final market = _parseOption(put, stock, false, underlyingPrice, errorsSink);
          if (market != null) {
            markets.add(market);
          }
        }
      }
      
      return markets;
    } catch (e) {
      errorsSink('Error fetching options for $ticker: $e');
      return [];
    }
  }
  
  static Market? _parseOption(
    Map<String, dynamic> data,
    Stock underlying,
    bool isCall,
    double underlyingPrice,
    void Function(String) errorListener,
  ) {
    try {
      final strike = (data['strike'] as num).toDouble();
      final expiration = DateTime.fromMillisecondsSinceEpoch(
        (data['expiration'] as int) * 1000,
        isUtc: true,
      );
      final lastPrice = (data['lastPrice'] as num?)?.toDouble() ?? 0.0;
      final bid = (data['bid'] as num?)?.toDouble();
      final ask = (data['ask'] as num?)?.toDouble();
      final volume = (data['volume'] as num?)?.toDouble();
      final openInterest = (data['openInterest'] as num?)?.toDouble();
      final impliedVol = (data['impliedVolatility'] as num?)?.toDouble();
      final dte = (data['daysToExpiration'] as num?)?.toDouble() ?? 
          expiration.difference(DateTime.now()).inDays.toDouble();
      
      final contractSymbol = data['contractSymbol'] as String? ?? 
          '${underlying.symbol}_${isCall ? 'C' : 'P'}_${strike}_${expiration.millisecondsSinceEpoch ~/ 1000}';
      
      if (bid == null || ask == null || bid <= 0 || ask <= 0) {
        // Skip options without valid bid/ask
        return null;
      }
      
      final option = StockOption(
        contractSymbol,
        contractSymbol,
        underlying: underlying,
        strike: strike,
        expiration: expiration,
        daysToExpiration: dte,
        isCall: isCall,
        isPut: !isCall,
        lastPrice: lastPrice,
        bid: bid,
        ask: ask,
        volume: volume,
        openInterest: openInterest,
        impliedVolatility: impliedVol,
        contractLot: 100,
      );
      
      return Market.create(
        asset: option,
        money: Stock('USD', 'USD'),
        bidPrice: bid,
        askPrice: ask,
      );
    } catch (e) {
      errorListener('Error parsing option: $e');
      return null;
    }
  }
  
  static Future<double> fetchStockPrice(String ticker, UrlFetcher urlFetcher) async {
    final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$ticker?interval=1d&range=1d';
    
    try {
      final responseJson = await urlFetcher.fetch(url);
      final data = json.decode(responseJson) as Map<String, dynamic>;
      
      final result = data['chart']?['result']?[0];
      if (result == null) return 0.0;
      
      final meta = result['meta'] as Map<String, dynamic>?;
      final price = meta?['regularMarketPrice']?.toDouble() ??
          meta?['previousClose']?.toDouble() ??
          0.0;
      
      return price;
    } catch (e) {
      return 0.0;
    }
  }
}
