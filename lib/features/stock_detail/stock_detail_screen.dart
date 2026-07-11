import 'dart:math';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../data/market_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../futures/futures_trade_sheet.dart';

class StockDetailScreen extends ConsumerStatefulWidget {
  final String stockSymbol;
  final bool isFutures;
  const StockDetailScreen({required this.stockSymbol, this.isFutures = false, super.key});

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  String _range = '1D';
  bool _isCandle = true;
  int _selectedTab = 0;
  late ZoomPanBehavior _zoomPanBehavior;
  DateTimeAxisController? _xAxisController;
  NumericAxisController? _yAxisController;
  
  List<StockCandle>? _rangeCandles;
  bool _isLoadingRange = false;

  @override
  void initState() {
    super.initState();
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      zoomMode: ZoomMode.xy,
    );
    _fetchRangeData('1D', widget.stockSymbol);
  }

  Future<void> _fetchRangeData(String range, String symbol) async {
    setState(() { _isLoadingRange = true; _range = range; });
    String interval = '15m';
    int limit = 96;
    switch(range) {
      case '1D': interval = '15m'; limit = 96; break;
      case '1W': interval = '2h'; limit = 84; break;
      case '1M': interval = '8h'; limit = 90; break;
      case '1Y': interval = '1d'; limit = 365; break;
      case '5Y': interval = '1w'; limit = 260; break;
    }
    try {
      final res = await http.get(Uri.parse('https://api.binance.com/api/v3/klines?symbol=${symbol}USDT&interval=$interval&limit=$limit'));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final candles = data.map((d) => StockCandle(
          date: DateTime.fromMillisecondsSinceEpoch(d[0] as int),
          open: double.parse(d[1].toString()) * CurrencyFormatters.usdToInr,
          high: double.parse(d[2].toString()) * CurrencyFormatters.usdToInr,
          low: double.parse(d[3].toString()) * CurrencyFormatters.usdToInr,
          close: double.parse(d[4].toString()) * CurrencyFormatters.usdToInr,
          volume: double.parse(d[5].toString()),
        )).toList();
        if (mounted) setState(() { _rangeCandles = candles; _isLoadingRange = false; });
      } else {
        if (mounted) setState(() { _isLoadingRange = false; });
      }
    } catch(e) {
      if (mounted) setState(() { _isLoadingRange = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final market = ref.watch(marketProvider);
    final userState = ref.watch(userProvider);
    final stock = market.firstWhere((s) => s.symbol == widget.stockSymbol);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    final isWatched = userState.profile.watchlist.contains(stock.symbol);
    final holding = userState.holdings.firstWhere((h) => h.symbol == stock.symbol, orElse: () => Holding(symbol: stock.symbol, quantity: 0, averagePrice: 0));

    final good = stock.changePercentage >= 0;
    final color = good ? AppColors.profit : AppColors.loss;

    // Show loading state while history hasn't loaded from API yet
    if (stock.history.length < 2) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(stock.symbol),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              const SizedBox(height: 16),
              Text(
                'Loading ${stock.name} data...',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Use fetched candles or fallback to cache
    final activeCandles = _rangeCandles ?? stock.candleHistory;
    final spots = activeCandles.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.close)).toList();
    
    final minPrice = activeCandles.isEmpty ? stock.currentPrice : activeCandles.map((c) => c.low).reduce(min);
    final maxPrice = activeCandles.isEmpty ? stock.currentPrice : activeCandles.map((c) => c.high).reduce(max);
    
    final yMin = minPrice * 0.99;
    final yMax = maxPrice * 1.01;
    final yRange = yMax - yMin;
    
    double visibleMin = yMin;
    double visibleMax = yMax;
    
    if (_yAxisController != null) {
      visibleMin = yMin + (yRange * _yAxisController!.zoomPosition);
      visibleMax = visibleMin + (yRange * _yAxisController!.zoomFactor);
    }

    final sliverAppBar = SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      title: Text(stock.symbol, style: const TextStyle(fontWeight: FontWeight.w900)),
      actions: [
        IconButton(
          onPressed: () => ref.read(userProvider.notifier).toggleWatchlist(stock.symbol),
          icon: Icon(isWatched ? Icons.star : Icons.star_border, color: isWatched ? Colors.amber : Colors.white60),
        ),
      ],
    );

    final headerWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stock.name, style: const TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatter.format(stock.currentPrice),
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final chartWidget = SizedBox(
      height: 400,
      child: Stack(
        children: [
          Positioned.fill(
            child: _isCandle ? SfCartesianChart(
              trackballBehavior: TrackballBehavior(
                enable: true,
                activationMode: ActivationMode.singleTap,
                tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
                tooltipSettings: const InteractiveTooltip(
                  enable: true, 
                  color: Color(0xFF2B3139),
                  textStyle: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              zoomPanBehavior: _zoomPanBehavior,
              primaryXAxis: DateTimeAxis(
                onRendererCreated: (controller) => _xAxisController = controller,
                isVisible: true, 
                majorGridLines: const MajorGridLines(width: 0)
              ),
              primaryYAxis: NumericAxis(
                onRendererCreated: (controller) => _yAxisController = controller,
                isVisible: true, 
                opposedPosition: true, 
                minimum: minPrice * 0.99, 
                maximum: maxPrice * 1.01, 
                majorGridLines: const MajorGridLines(width: 0.5, color: Colors.white10),
              ),
              plotAreaBorderWidth: 0,
              margin: EdgeInsets.zero,
              series: <CartesianSeries<StockCandle, DateTime>>[
                CandleSeries<StockCandle, DateTime>(
                  name: stock.symbol,
                  dataSource: activeCandles.isEmpty ? [StockCandle(date: DateTime.now(), open: stock.currentPrice, high: stock.currentPrice, low: stock.currentPrice, close: stock.currentPrice, volume: 0)] : activeCandles,
                  xValueMapper: (StockCandle s, _) => s.date,
                  lowValueMapper: (StockCandle s, _) => s.low,
                  highValueMapper: (StockCandle s, _) => s.high,
                  openValueMapper: (StockCandle s, _) => s.open,
                  closeValueMapper: (StockCandle s, _) => s.close,
                  bearColor: AppColors.loss,
                  bullColor: AppColors.profit,
                  enableSolidCandles: true,
                )
              ],
            ) : LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white10, strokeWidth: 1)),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minY: minPrice * 0.99,
                maxY: maxPrice * 1.01,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoadingRange)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: ['1D', '1W', '1M', '1Y', '5Y'].map((r) {
                      final isSelected = _range == r;
                      return GestureDetector(
                        onTap: () {
                          if (_range != r) {
                            _fetchRangeData(r, widget.stockSymbol);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white24 : Colors.transparent,
                            borderRadius: BorderRadius.circular(16)
                          ),
                          child: Text(r, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _isCandle = !_isCandle),
                  icon: Icon(_isCandle ? Icons.show_chart : Icons.candlestick_chart, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.5)),
                )
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 30,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) {
                if (_xAxisController != null) {
                  double currentFactor = _xAxisController!.zoomFactor;
                  double currentPos = _xAxisController!.zoomPosition;
                  double rightEdge = currentPos + currentFactor;
                  double newFactor = currentFactor - (details.primaryDelta! * 0.005);
                  newFactor = newFactor.clamp(0.05, 1.0);
                  double newPos = rightEdge - newFactor;
                  newPos = newPos.clamp(0.0, 1.0 - newFactor);
                  _xAxisController!.zoomFactor = newFactor;
                  _xAxisController!.zoomPosition = newPos;
                }
              },
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 50,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                if (_yAxisController != null) {
                  double currentFactor = _yAxisController!.zoomFactor;
                  double currentPos = _yAxisController!.zoomPosition;
                  double center = currentPos + (currentFactor / 2);
                  double newFactor = currentFactor + (details.primaryDelta! * 0.005);
                  newFactor = newFactor.clamp(0.05, 1.0);
                  double newPos = center - (newFactor / 2);
                  newPos = newPos.clamp(0.0, 1.0 - newFactor);
                  _yAxisController!.zoomFactor = newFactor;
                  _yAxisController!.zoomPosition = newPos;
                  setState(() {});
                }
              },
            ),
          ),
        ],
      ),
    );

    final tabsWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            _buildTab(0, 'Order Book'),
            const SizedBox(width: 24),
            _buildTab(1, 'Positions'),
            const SizedBox(width: 24),
            _buildTab(2, 'Info'),
          ],
        ),
      ),
    );

    final contentWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildTabContent(stock, holding, userState, formatter),
    );

    final buySellBar = ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.7),
            border: const Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openTradeSheet(context, stock, OrderSide.sell, widget.isFutures),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    foregroundColor: AppColors.loss,
                    side: const BorderSide(color: AppColors.loss, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(widget.isFutures ? 'SHORT' : 'SELL', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: () => _openTradeSheet(context, stock, OrderSide.buy, widget.isFutures),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: AppColors.profit,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(widget.isFutures ? 'LONG' : 'BUY', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;

          if (isDesktop) {
            return Row(
              children: [
                Expanded(
                  flex: 6,
                  child: CustomScrollView(
                    slivers: [
                      sliverAppBar,
                      SliverToBoxAdapter(child: headerWidget),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      SliverToBoxAdapter(child: chartWidget),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Colors.white10),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              tabsWidget,
                              const SizedBox(height: 20),
                              contentWidget,
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                      buySellBar,
                    ],
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  sliverAppBar,
                  SliverToBoxAdapter(child: headerWidget),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(child: chartWidget),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          tabsWidget,
                          const SizedBox(height: 20),
                          contentWidget,
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: buySellBar,
              ),
            ],
          );
        },
      ),
    );
  }

  void _openTradeSheet(BuildContext context, Stock stock, OrderSide side, bool isFutures) {
    if (isFutures) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => FuturesTradeSheet(stock: stock, initialSide: side),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _TradeSheet(stock: stock, initialSide: side),
      );
    }
  }

  Widget _buildTab(int index, String title) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(Stock stock, Holding holding, UserState userState, AppCurrencyFormatter formatter) {
    if (_selectedTab == 0) {
      return _OrderBookWidget(stock: stock);
    } else if (_selectedTab == 1) {
      final trades = userState.trades.where((t) => t.symbol == stock.symbol).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (holding.quantity > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Owned', style: TextStyle(color: Colors.white60)),
                      Text('${holding.quantity} ${stock.symbol}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Avg Buy Price', style: TextStyle(color: Colors.white60)),
                      Text(formatter.format(holding.averagePrice), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Return', style: TextStyle(color: Colors.white60)),
                      Text(
                        formatter.format((stock.currentPrice - holding.averagePrice) * holding.quantity),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: (stock.currentPrice - holding.averagePrice) >= 0 ? AppColors.profit : AppColors.loss,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else
            const Text('You have no open positions for this asset.', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 24),
          const Text('Trade History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          if (trades.isEmpty)
            const Text('No trades yet.', style: TextStyle(color: Colors.white60))
          else
            ...trades.reversed.map((t) => _TradeHistoryTile(t)),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Market Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard('Market Cap', AppCompactCurrencyFormatter(userState.profile.preferredCurrency).format(stock.marketCap))),
              const SizedBox(width: 8),
              Expanded(child: _StatCard('Volume (24h)', NumberFormat.compact().format(stock.volume))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _StatCard('Circulating Supply', '${NumberFormat.compact().format(stock.supply)} ${stock.symbol}')),
              const SizedBox(width: 8),
              Expanded(child: _StatCard('Popularity Rank', '#${stock.rank}')),
            ],
          ),
          const SizedBox(height: 24),
          const Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Text(
            stock.about,
            style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 15),
          ),
        ],
      );
    }
  }
}

class _OrderBookWidget extends ConsumerWidget {
  final Stock stock;
  const _OrderBookWidget({required this.stock});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    final random = Random(stock.currentPrice.toInt() + DateTime.now().second);
    
    final asks = List.generate(8, (i) {
      final price = stock.currentPrice + (random.nextDouble() * stock.currentPrice * 0.001) + (i * stock.currentPrice * 0.0005);
      final qty = random.nextDouble() * 5 + 0.1;
      return (price, qty);
    }).reversed.toList();

    final bids = List.generate(8, (i) {
      final price = stock.currentPrice - (random.nextDouble() * stock.currentPrice * 0.001) - (i * stock.currentPrice * 0.0005);
      final qty = random.nextDouble() * 5 + 0.1;
      return (price, qty);
    });

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bid Qty', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('Bid Price', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              ...bids.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(b.$2.toStringAsFixed(3), style: const TextStyle(color: Colors.white70)),
                    Text(formatter.format(b.$1), style: const TextStyle(color: AppColors.profit, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              )),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ask Price', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('Ask Qty', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              ...asks.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatter.format(a.$1), style: const TextStyle(color: AppColors.loss, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(a.$2.toStringAsFixed(3), style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }
}

class _TradeHistoryTile extends ConsumerWidget {
  final Trade trade;
  const _TradeHistoryTile(this.trade);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final isBuy = trade.side == OrderSide.buy;
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(isBuy ? Icons.arrow_downward : Icons.arrow_upward, color: isBuy ? AppColors.profit : AppColors.loss, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isBuy ? 'Bought' : 'Sold', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(trade.time.toString().split('.')[0], style: const TextStyle(fontSize: 12, color: Colors.white54)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatter.format(trade.price), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${trade.quantity} ${trade.symbol}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}

class _TradeSheet extends ConsumerStatefulWidget {
  final Stock stock;
  final OrderSide initialSide;
  const _TradeSheet({required this.stock, required this.initialSide});

  @override
  ConsumerState<_TradeSheet> createState() => _TradeSheetState();
}

class _TradeSheetState extends ConsumerState<_TradeSheet> {
  late OrderSide _side;
  bool _isCryptoInput = true;
  final _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide;
  }

  double get _inputVal => double.tryParse(_inputController.text) ?? 0.0;
  int get _cryptoQty => _isCryptoInput ? _inputVal.floor() : (_inputVal / widget.stock.currentPrice).floor();
  double get _fiatAmount => _isCryptoInput ? (_inputVal * widget.stock.currentPrice) : _inputVal;

  int _getOwnedQty(UserState state) {
    final h = state.holdings.firstWhere((e) => e.symbol == widget.stock.symbol, orElse: () => Holding(symbol: widget.stock.symbol, quantity: 0, averagePrice: 0));
    return h.quantity;
  }

  void _setPercentage(double pct, UserState state) {
    if (_side == OrderSide.buy) {
      final maxFiat = state.profile.virtualBalance;
      final targetFiat = maxFiat * pct;
      if (_isCryptoInput) {
        _inputController.text = (targetFiat / widget.stock.currentPrice).floor().toString();
      } else {
        _inputController.text = targetFiat.toStringAsFixed(2);
      }
    } else {
      final maxQty = _getOwnedQty(state);
      final targetQty = (maxQty * pct).floor();
      if (_isCryptoInput) {
        _inputController.text = targetQty.toString();
      } else {
        _inputController.text = (targetQty * widget.stock.currentPrice).toStringAsFixed(2);
      }
    }
    setState((){});
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    final currSym = CurrencyFormatters.getSymbol(userState.profile.preferredCurrency);
    
    final isBuy = _side == OrderSide.buy;
    final ownedQty = _getOwnedQty(userState);
    final totalCost = _cryptoQty * widget.stock.currentPrice;
    final fee = totalCost * 0.001;
    final totalWithFee = isBuy ? totalCost + fee : totalCost - fee;

    final canExecute = _cryptoQty > 0 && (isBuy ? totalWithFee <= userState.profile.virtualBalance : _cryptoQty <= ownedQty);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _side = OrderSide.buy),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isBuy ? AppColors.profit : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text('Buy', style: TextStyle(fontWeight: FontWeight.bold, color: isBuy ? Colors.white : Colors.white54)),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _side = OrderSide.sell),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !isBuy ? AppColors.loss : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text('Sell', style: TextStyle(fontWeight: FontWeight.bold, color: !isBuy ? Colors.white : Colors.white54)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isBuy ? 'Available: ${formatter.format(userState.profile.virtualBalance)}' : 'Available: $ownedQty ${widget.stock.symbol}', style: const TextStyle(color: Colors.white60)),
              GestureDetector(
                onTap: () => setState(() {
                  _isCryptoInput = !_isCryptoInput;
                  _inputController.clear();
                }),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz, size: 16, color: Colors.blueAccent),
                    const SizedBox(width: 4),
                    Text(_isCryptoInput ? 'Input in $currSym' : 'Input in ${widget.stock.symbol}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inputController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              labelText: _isCryptoInput ? 'Amount (${widget.stock.symbol})' : 'Amount ($currSym)',
              labelStyle: const TextStyle(fontSize: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surface,
              suffixText: _isCryptoInput ? widget.stock.symbol : currSym,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_inputVal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 4),
              child: Text(
                _isCryptoInput ? '≈ ${formatter.format(_fiatAmount)}' : '≈ $_cryptoQty ${widget.stock.symbol}',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPctBtn('25%', 0.25, userState),
              _buildPctBtn('50%', 0.50, userState),
              _buildPctBtn('75%', 0.75, userState),
              _buildPctBtn('MAX', 1.0, userState),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Market price', style: TextStyle(color: Colors.white60)), Text(formatter.format(widget.stock.currentPrice), style: const TextStyle(fontWeight: FontWeight.bold))]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Estimated value', style: TextStyle(color: Colors.white60)), Text(formatter.format(totalCost), style: const TextStyle(fontWeight: FontWeight.bold))]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Est. Trading Fee (0.1%)', style: TextStyle(color: Colors.white60)), Text(formatter.format(fee), style: const TextStyle(fontWeight: FontWeight.bold))]),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white10)),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(formatter.format(totalWithFee), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]),
              ],
            ),
          ),
          if (_inputVal > 0 && _cryptoQty <= 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 8),
                  Text('Minimum order is 1 ${widget.stock.symbol} (${formatter.format(widget.stock.currentPrice)})', style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else if (_inputVal > 0 && isBuy && totalWithFee > userState.profile.virtualBalance)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.loss, size: 16),
                  SizedBox(width: 8),
                  Text('Insufficient available balance', style: TextStyle(color: AppColors.loss, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else if (_inputVal > 0 && !isBuy && _cryptoQty > ownedQty)
             Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.loss, size: 16),
                  const SizedBox(width: 8),
                  Text('Insufficient ${widget.stock.symbol} balance', style: const TextStyle(color: AppColors.loss, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canExecute ? () {
              final success = ref.read(userProvider.notifier).tradeStock(widget.stock, _side, _cryptoQty);
              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order executed successfully!'), backgroundColor: AppColors.profit));
              }
            } : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: isBuy ? AppColors.profit : AppColors.loss,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(isBuy ? 'Confirm Buy' : 'Confirm Sell', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPctBtn(String label, double pct, UserState state) {
    return GestureDetector(
      onTap: () => _setPercentage(pct, state),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}
