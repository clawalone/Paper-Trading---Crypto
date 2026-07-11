import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../core/currency_formatters.dart';
import 'models.dart';

final marketProvider = NotifierProvider<MarketNotifier, List<Stock>>(() {
  return MarketNotifier();
});

class MarketNotifier extends Notifier<List<Stock>> {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;

  // ── 50 coins across all major categories ─────────────────────────────────
  static const _cryptoAssets = [
    // Layer 1
    ('BTCUSDT',  'Bitcoin',         'Layer 1'),
    ('ETHUSDT',  'Ethereum',        'Layer 1'),
    ('SOLUSDT',  'Solana',          'Layer 1'),
    ('ADAUSDT',  'Cardano',         'Layer 1'),
    ('AVAXUSDT', 'Avalanche',       'Layer 1'),
    ('DOTUSDT',  'Polkadot',        'Layer 1'),
    ('ATOMUSDT', 'Cosmos',          'Layer 1'),
    ('NEARUSDT', 'NEAR Protocol',   'Layer 1'),
    ('APTUSDT',  'Aptos',           'Layer 1'),
    ('SUIUSDT',  'Sui',             'Layer 1'),
    ('ALGOUSDT', 'Algorand',        'Layer 1'),
    ('XLMUSDT',  'Stellar',         'Layer 1'),
    ('TRXUSDT',  'TRON',            'Layer 1'),
    ('HBARUSDT', 'Hedera',          'Layer 1'),

    // Layer 2 / Scaling
    ('MATICUSDT','Polygon',         'Layer 2'),
    ('OPUSDT',   'Optimism',        'Layer 2'),
    ('ARBUSDT',  'Arbitrum',        'Layer 2'),
    ('STXUSDT',  'Stacks',          'Layer 2'),
    ('IMXUSDT',  'ImmutableX',      'Layer 2'),

    // Exchange / Utility
    ('BNBUSDT',  'BNB',             'Exchange'),
    ('FTMUSDT',  'Fantom',          'Layer 1'),
    ('GMXUSDT',  'GMX',             'DeFi'),

    // DeFi
    ('UNIUSDT',  'Uniswap',         'DeFi'),
    ('AAVEUSDT', 'Aave',            'DeFi'),
    ('MKRUSDT',  'Maker',           'DeFi'),
    ('CRVUSDT',  'Curve DAO',       'DeFi'),
    ('COMPUSDT', 'Compound',        'DeFi'),
    ('SNXUSDT',  'Synthetix',       'DeFi'),
    ('LDOUSDT',  'Lido DAO',        'DeFi'),
    ('JUPUSDT',  'Jupiter',         'DeFi'),

    // Infrastructure / Oracle
    ('LINKUSDT', 'Chainlink',       'Infrastructure'),
    ('GRTUSDT',  'The Graph',       'Infrastructure'),
    ('FILUSDT',  'Filecoin',        'Infrastructure'),
    ('RENDERUSDT','Render',         'Infrastructure'),
    ('FETUSDT',  'Fetch.ai',        'Infrastructure'),
    ('INJUSDT',  'Injective',       'Infrastructure'),

    // Payments / Cross-chain
    ('XRPUSDT',  'Ripple',          'Payments'),
    ('LTCUSDT',  'Litecoin',        'Payments'),
    ('BCHUSDT',  'Bitcoin Cash',    'Payments'),

    // Gaming / Metaverse
    ('SANDUSDT', 'The Sandbox',     'Gaming'),
    ('MANAUSDT', 'Decentraland',    'Gaming'),
    ('AXSUSDT',  'Axie Infinity',   'Gaming'),
    ('GALAUSDT', 'Gala',            'Gaming'),

    // AI / Data
    ('WLDUSDT',  'Worldcoin',       'AI'),
    ('TAOUSDT',  'Bittensor',       'AI'),
    ('AGIXUSDT', 'SingularityNET',  'AI'),

    // Meme
    ('DOGEUSDT', 'Dogecoin',        'Meme'),
    ('SHIBUSDT', 'Shiba Inu',       'Meme'),
    ('PEPEUSDT', 'Pepe',            'Meme'),
    ('FLOKIUSDT','Floki',           'Meme'),
  ];

  static const _assetDetails = <String, Map<String, Object>>{
    'BTC':    {'about': 'Bitcoin is the first decentralized cryptocurrency, created by Satoshi Nakamoto in 2009.', 'supply': 19700000.0, 'rank': 1},
    'ETH':    {'about': 'Ethereum is a decentralized platform for smart contracts and dApps, created by Vitalik Buterin.', 'supply': 120000000.0, 'rank': 2},
    'SOL':    {'about': 'Solana is a high-performance blockchain supporting fast, low-cost transactions and dApps.', 'supply': 450000000.0, 'rank': 5},
    'ADA':    {'about': 'Cardano is a proof-of-stake blockchain platform focused on security and sustainability.', 'supply': 35000000000.0, 'rank': 10},
    'AVAX':   {'about': 'Avalanche is a smart contract platform designed for DeFi with near-instant transaction finality.', 'supply': 400000000.0, 'rank': 11},
    'DOT':    {'about': 'Polkadot enables cross-blockchain transfers of any data or asset type.', 'supply': 1300000000.0, 'rank': 14},
    'ATOM':   {'about': 'Cosmos is an ecosystem of blockchains connected through IBC protocol.', 'supply': 290000000.0, 'rank': 22},
    'NEAR':   {'about': 'NEAR Protocol is a sharded proof-of-stake blockchain designed for scalability.', 'supply': 1000000000.0, 'rank': 18},
    'APT':    {'about': 'Aptos is a Layer 1 blockchain built on Move language, focused on safety and upgradability.', 'supply': 1000000000.0, 'rank': 30},
    'SUI':    {'about': 'Sui is a Layer 1 blockchain and smart contract platform designed for instant finality.', 'supply': 10000000000.0, 'rank': 27},
    'ALGO':   {'about': 'Algorand is a self-sustaining, decentralized blockchain network supporting a wide range of applications.', 'supply': 10000000000.0, 'rank': 40},
    'XLM':    {'about': 'Stellar is an open blockchain network connecting financial institutions for low-cost transactions.', 'supply': 50000000000.0, 'rank': 28},
    'TRX':    {'about': 'TRON is a blockchain platform focused on content sharing and entertainment.', 'supply': 88000000000.0, 'rank': 12},
    'HBAR':   {'about': 'Hedera is an enterprise-grade public network using hashgraph consensus.', 'supply': 50000000000.0, 'rank': 32},
    'MATIC':  {'about': 'Polygon (MATIC) is a scaling solution for Ethereum, providing faster and cheaper transactions.', 'supply': 10000000000.0, 'rank': 16},
    'OP':     {'about': 'Optimism is an Ethereum Layer 2 optimistic rollup scaling solution.', 'supply': 4294967296.0, 'rank': 38},
    'ARB':    {'about': 'Arbitrum is a leading Ethereum Layer 2 scaling solution using optimistic rollups.', 'supply': 10000000000.0, 'rank': 33},
    'STX':    {'about': 'Stacks is a Layer 2 for Bitcoin, enabling smart contracts and dApps on Bitcoin.', 'supply': 1818000000.0, 'rank': 55},
    'IMX':    {'about': 'ImmutableX is a Layer 2 for NFTs on Ethereum with zero gas fees.', 'supply': 2000000000.0, 'rank': 60},
    'BNB':    {'about': 'BNB powers the BNB Chain ecosystem and is used for transaction fees on Binance.', 'supply': 153000000.0, 'rank': 4},
    'FTM':    {'about': 'Fantom is a highly scalable blockchain platform for DeFi, crypto dApps, and enterprise applications.', 'supply': 2800000000.0, 'rank': 50},
    'GMX':    {'about': 'GMX is a decentralized spot and perpetual exchange that supports low swap fees and zero price impact trades.', 'supply': 9000000.0, 'rank': 65},
    'UNI':    {'about': 'Uniswap is the largest decentralized exchange protocol on Ethereum.', 'supply': 1000000000.0, 'rank': 21},
    'AAVE':   {'about': 'Aave is a decentralized non-custodial liquidity protocol for earning interest.', 'supply': 16000000.0, 'rank': 35},
    'MKR':    {'about': 'Maker is the governance token of the MakerDAO protocol, which issues the DAI stablecoin.', 'supply': 977631.0, 'rank': 42},
    'CRV':    {'about': 'Curve is a decentralized exchange optimized for stablecoin trading with low fees.', 'supply': 3303030299.0, 'rank': 70},
    'COMP':   {'about': 'Compound is an algorithmic, autonomous interest rate protocol for DeFi lending.', 'supply': 10000000.0, 'rank': 80},
    'SNX':    {'about': 'Synthetix is a decentralized protocol for synthetic assets on Ethereum.', 'supply': 300000000.0, 'rank': 75},
    'LDO':    {'about': 'Lido DAO governs the Lido liquid staking protocol for ETH and other assets.', 'supply': 1000000000.0, 'rank': 44},
    'JUP':    {'about': 'Jupiter is the leading DEX aggregator on Solana.', 'supply': 10000000000.0, 'rank': 36},
    'LINK':   {'about': 'Chainlink is a decentralized oracle network providing real-world data to smart contracts.', 'supply': 1000000000.0, 'rank': 15},
    'GRT':    {'about': 'The Graph is an indexing protocol for querying blockchain data.', 'supply': 10000000000.0, 'rank': 62},
    'FIL':    {'about': 'Filecoin is a decentralized storage network to store the world\'s most important information.', 'supply': 2000000000.0, 'rank': 53},
    'RENDER': {'about': 'Render Network is a decentralized GPU rendering platform.', 'supply': 536870912.0, 'rank': 45},
    'FET':    {'about': 'Fetch.ai is an AI-powered blockchain platform for autonomous agents.', 'supply': 1152997575.0, 'rank': 58},
    'INJ':    {'about': 'Injective is a DeFi blockchain optimized for trading applications.', 'supply': 100000000.0, 'rank': 37},
    'XRP':    {'about': 'XRP is the native asset of the XRP Ledger, used for fast and low-cost global payments.', 'supply': 55000000000.0, 'rank': 6},
    'LTC':    {'about': 'Litecoin is a peer-to-peer cryptocurrency based on the Bitcoin protocol.', 'supply': 84000000.0, 'rank': 20},
    'BCH':    {'about': 'Bitcoin Cash is a fork of Bitcoin with larger block sizes for faster transactions.', 'supply': 21000000.0, 'rank': 24},
    'SAND':   {'about': 'The Sandbox is a virtual gaming metaverse powered by blockchain.', 'supply': 3000000000.0, 'rank': 72},
    'MANA':   {'about': 'Decentraland is a virtual world where users can buy, sell, and build on virtual land.', 'supply': 2194000000.0, 'rank': 76},
    'AXS':    {'about': 'Axie Infinity is a blockchain-based trading and battling game.', 'supply': 270000000.0, 'rank': 66},
    'GALA':   {'about': 'Gala Games is a blockchain gaming platform building player-owned games.', 'supply': 50000000000.0, 'rank': 85},
    'WLD':    {'about': 'Worldcoin is a global digital identity and financial network.', 'supply': 10000000000.0, 'rank': 48},
    'TAO':    {'about': 'Bittensor is a decentralized machine learning network.', 'supply': 21000000.0, 'rank': 43},
    'AGIX':   {'about': 'SingularityNET is a decentralized AI marketplace and network.', 'supply': 2000000000.0, 'rank': 78},
    'DOGE':   {'about': 'Dogecoin started as a meme but grew into one of the largest cryptocurrencies by market cap.', 'supply': 144000000000.0, 'rank': 8},
    'SHIB':   {'about': 'Shiba Inu is an Ethereum-based meme token with a large community.', 'supply': 589000000000000.0, 'rank': 13},
    'PEPE':   {'about': 'Pepe is a deflationary memecoin launched on Ethereum as a tribute to the Pepe the Frog meme.', 'supply': 420690000000000.0, 'rank': 25},
    'FLOKI':  {'about': 'Floki is a community-driven cryptocurrency inspired by Elon Musk\'s dog.', 'supply': 9897070000000.0, 'rank': 90},
  };

  // Fallback for assets without specific details
  static Map<String, Object> _defaultDetails(String sym) => {
    'about': '$sym is a cryptocurrency asset traded on major exchanges.',
    'supply': 1000000000.0,
    'rank': 999,
  };

  @override
  List<Stock> build() {
    _initLiveMarket();
    ref.onDispose(() {
      _channel?.sink.close();
      _reconnectTimer?.cancel();
    });

    // Return placeholder list while loading
    return _cryptoAssets.map((c) {
      final sym = c.$1.replaceAll('USDT', '');
      final details = _assetDetails[sym] ?? _defaultDetails(sym);
      return Stock(
        symbol: sym,
        name: c.$2,
        category: c.$3,
        currentPrice: 0,
        previousClose: 0,
        dayHigh: 0,
        dayLow: 0,
        volume: 0,
        history: const [],
        candleHistory: const [],
        about: details['about'] as String,
        supply: (details['supply'] as num).toDouble(),
        rank: details['rank'] as int,
      );
    }).toList();
  }

  Future<void> _initLiveMarket() async {
    // ── Step 1: Fetch 24h tickers for all coins at once (single REST call) ──
    try {
      final symbols = '[${_cryptoAssets.map((c) => '"${c.$1}"').join(',')}]';
      final tickerRes = await http.get(
        Uri.parse('https://api.binance.com/api/v3/ticker/24hr?symbols=${Uri.encodeComponent(symbols)}'),
      );

      if (tickerRes.statusCode == 200) {
        final List<dynamic> tickers = jsonDecode(tickerRes.body);
        final tickerMap = {for (final t in tickers) t['symbol'] as String: t};

        // ── Step 2: Fetch klines for all coins in parallel (batched) ────────
        // Split into batches of 10 to avoid rate limiting
        final batches = <List<(String, String, String)>>[];
        for (var i = 0; i < _cryptoAssets.length; i += 10) {
          batches.add(_cryptoAssets.skip(i).take(10).toList());
        }

        final allHistoryMap = <String, Map<String, dynamic>>{};

        for (final batch in batches) {
          final batchFutures = batch.map((asset) async {
            final symbol = asset.$1;
            try {
              final res = await http.get(Uri.parse(
                'https://api.binance.com/api/v3/klines?symbol=$symbol&interval=1h&limit=72',
              ));
              if (res.statusCode == 200) {
                final List<dynamic> data = jsonDecode(res.body);
                final candles = data.map((d) => StockCandle(
                  date: DateTime.fromMillisecondsSinceEpoch(d[0] as int),
                  open:   double.parse(d[1].toString()) * CurrencyFormatters.usdToInr,
                  high:   double.parse(d[2].toString()) * CurrencyFormatters.usdToInr,
                  low:    double.parse(d[3].toString()) * CurrencyFormatters.usdToInr,
                  close:  double.parse(d[4].toString()) * CurrencyFormatters.usdToInr,
                  volume: double.parse(d[5].toString()),
                )).toList();
                return MapEntry(symbol, {
                  'candles': candles,
                  'history': candles.map((c) => c.close).toList(),
                });
              }
            } catch (_) {}
            return MapEntry(symbol, <String, dynamic>{});
          }).toList();

          final results = await Future.wait(batchFutures);
          for (final entry in results) {
            if (entry.value.isNotEmpty) {
              allHistoryMap[entry.key] = entry.value;
            }
          }

          // Small delay between batches to be polite to the API
          await Future.delayed(const Duration(milliseconds: 200));
        }

        // ── Step 3: Build initial state ──────────────────────────────────────
        final initialState = _cryptoAssets.map((c) {
          final sym = c.$1.replaceAll('USDT', '');
          final details = _assetDetails[sym] ?? _defaultDetails(sym);
          final ticker = tickerMap[c.$1];
          final h = allHistoryMap[c.$1];

          final currentPrice = ticker != null
              ? (double.tryParse(ticker['lastPrice'].toString()) ?? 0.0) * CurrencyFormatters.usdToInr
              : 0.0;
          final openPrice = ticker != null
              ? (double.tryParse(ticker['openPrice'].toString()) ?? 0.0) * CurrencyFormatters.usdToInr
              : 0.0;
          final highPrice = ticker != null
              ? (double.tryParse(ticker['highPrice'].toString()) ?? 0.0) * CurrencyFormatters.usdToInr
              : 0.0;
          final lowPrice = ticker != null
              ? (double.tryParse(ticker['lowPrice'].toString()) ?? 0.0) * CurrencyFormatters.usdToInr
              : 0.0;
          final volume = ticker != null
              ? (double.tryParse(ticker['volume'].toString()) ?? 0.0).toInt()
              : 0;

          return Stock(
            symbol: sym,
            name: c.$2,
            category: c.$3,
            currentPrice: currentPrice,
            previousClose: openPrice,
            dayHigh: highPrice,
            dayLow: lowPrice,
            volume: volume,
            history: (h?['history'] as List<double>?) ?? const [],
            candleHistory: (h?['candles'] as List<StockCandle>?) ?? const [],
            about: details['about'] as String,
            supply: (details['supply'] as num).toDouble(),
            rank: details['rank'] as int,
          );
        }).toList();

        state = initialState;
      }
    } catch (_) {}

    // ── Step 4: WebSocket for live ticker updates ────────────────────────────
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _channel?.sink.close();
      final streams = _cryptoAssets
          .map((c) => '${c.$1.toLowerCase()}@miniTicker')
          .join('/');

      _channel = WebSocketChannel.connect(
        Uri.parse('wss://stream.binance.com:9443/stream?streams=$streams'),
      );

      _channel!.stream.listen(
        (message) {
          try {
            final decoded = jsonDecode(message as String);
            if (decoded['data'] == null) return;
            final data = decoded['data'] as Map<String, dynamic>;

            final wsSymbol = data['s'] as String;           // e.g. BTCUSDT
            final displaySym = wsSymbol.replaceAll('USDT', '');
            final currentPrice = double.parse(data['c'].toString()) * CurrencyFormatters.usdToInr;
            final openPrice    = double.parse(data['o'].toString()) * CurrencyFormatters.usdToInr;
            final highPrice    = double.parse(data['h'].toString()) * CurrencyFormatters.usdToInr;
            final lowPrice     = double.parse(data['l'].toString()) * CurrencyFormatters.usdToInr;
            final volume       = (double.tryParse(data['v'].toString()) ?? 0).toInt();

            final idx = state.indexWhere((s) => s.symbol == displaySym);
            if (idx < 0) return;

            final old = state[idx];

            // Update last candle with live price
            final newCandles = List<StockCandle>.from(old.candleHistory);
            if (newCandles.isNotEmpty) {
              final last = newCandles.last;
              newCandles[newCandles.length - 1] = StockCandle(
                date:   last.date,
                open:   last.open,
                high:   max(last.high, currentPrice),
                low:    min(last.low, currentPrice),
                close:  currentPrice,
                volume: last.volume,
              );
            }

            final newHistory = List<double>.from(old.history);
            if (newHistory.isNotEmpty) {
              newHistory[newHistory.length - 1] = currentPrice;
            }

            final newState = List<Stock>.from(state);
            newState[idx] = Stock(
              symbol:        old.symbol,
              name:          old.name,
              category:      old.category,
              currentPrice:  currentPrice,
              previousClose: openPrice,
              dayHigh:       highPrice,
              dayLow:        lowPrice,
              volume:        volume,
              history:       newHistory,
              candleHistory: newCandles,
              about:         old.about,
              supply:        old.supply,
              rank:          old.rank,
            );
            state = newState;
          } catch (_) {}
        },
        onDone: () {
          // Auto-reconnect on disconnect
          _reconnectTimer = Timer(const Duration(seconds: 5), _connectWebSocket);
        },
        onError: (_) {
          _reconnectTimer = Timer(const Duration(seconds: 5), _connectWebSocket);
        },
      );
    } catch (_) {
      _reconnectTimer = Timer(const Duration(seconds: 5), _connectWebSocket);
    }
  }
}
