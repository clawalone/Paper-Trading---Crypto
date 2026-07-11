import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../core/app_theme.dart';
import '../../core/coin_icon.dart';
import '../../core/currency_formatters.dart';
import '../../data/market_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import 'futures_position_card.dart';

class FuturesProScreen extends ConsumerStatefulWidget {
  final String stockSymbol;
  const FuturesProScreen({required this.stockSymbol, super.key});

  @override
  ConsumerState<FuturesProScreen> createState() => _FuturesProScreenState();
}

class _FuturesProScreenState extends ConsumerState<FuturesProScreen> {
  int _selectedTab = 0; // 0: Trade, 1: Positions, 2: Orders
  OrderSide _side = OrderSide.buy;
  double _leverage = 20;
  final _qtyController = TextEditingController();
  bool _isInrInput = false; // false = input in coin, true = input in INR
  late ZoomPanBehavior _zoomPanBehavior;
  DateTimeAxisController? _xAxisController;
  NumericAxisController? _yAxisController;

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
  }

  double get _inputVal => double.tryParse(_qtyController.text) ?? 0.0;

  /// Quantity in coins
  double get _quantity => _isInrInput
      ? (_inputVal / _leverage > 0 ? _inputVal / _currentPrice : 0)
      : _inputVal;

  double _currentPrice = 0;

  void _setPercent(double pct, double balance, double price) {
    final maxInr = balance;
    if (_isInrInput) {
      _qtyController.text = (maxInr * pct).toStringAsFixed(2);
    } else {
      _qtyController.text = ((maxInr * pct) / price).toStringAsFixed(4);
    }
    setState(() {});
  }
  
  @override
  Widget build(BuildContext context) {
    final market = ref.watch(marketProvider);
    final userState = ref.watch(userProvider);
    final stock = market.firstWhere((s) => s.symbol == widget.stockSymbol, orElse: () => market.first);
    _currentPrice = stock.currentPrice;
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    final good = stock.changePercentage >= 0;
    final color = good ? AppColors.profit : AppColors.loss;

    if (stock.candleHistory.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text('${stock.symbol}-PERP', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              const SizedBox(height: 16),
              Text('Loading ${stock.symbol} chart...', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final minPrice = stock.candleHistory.isEmpty ? 0.0 : stock.candleHistory.map((c) => c.low).reduce(min);
    final maxPrice = stock.candleHistory.isEmpty ? 0.0 : stock.candleHistory.map((c) => c.high).reduce(max);
    
    final yMin = minPrice * 0.99;
    final yMax = maxPrice * 1.01;
    final yRange = yMax - yMin;
    
    double visibleMin = yMin;
    double visibleMax = yMax;
    
    if (_yAxisController != null) {
      visibleMin = yMin + (yRange * _yAxisController!.zoomPosition);
      visibleMax = visibleMin + (yRange * _yAxisController!.zoomFactor);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.bolt, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('${stock.symbol}-PERP', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: (good ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Text('${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%', style: TextStyle(color: good ? AppColors.profit : AppColors.loss, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.star_border)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;

          final chartWidget = Stack(
            children: [
              Positioned.fill(
                child: SfCartesianChart(
                  trackballBehavior: TrackballBehavior(
                    enable: true,
                    activationMode: ActivationMode.singleTap,
                    tooltipSettings: const InteractiveTooltip(enable: true, color: AppColors.surface),
                  ),
                  zoomPanBehavior: _zoomPanBehavior,
                  plotAreaBorderWidth: 0,
                  margin: EdgeInsets.zero,
                  primaryXAxis: DateTimeAxis(
                    onRendererCreated: (controller) => _xAxisController = controller,
                    isVisible: true,
                    majorGridLines: const MajorGridLines(width: 0),
                  ),
                  primaryYAxis: NumericAxis(
                    onRendererCreated: (controller) => _yAxisController = controller,
                    isVisible: true,
                    opposedPosition: true,
                    minimum: minPrice * 0.99,
                    maximum: maxPrice * 1.01,
                    majorGridLines: const MajorGridLines(width: 0.5, color: Colors.white10),
                  ),
                  axes: <ChartAxis>[
                    NumericAxis(
                      name: 'VolumeAxis',
                      opposedPosition: true,
                      isVisible: false,
                      minimum: 0,
                      maximum: stock.candleHistory.isEmpty ? 100 : stock.candleHistory.map((c) => c.volume).reduce(max) * 4,
                    )
                  ],
                  series: <CartesianSeries>[
                    ColumnSeries<StockCandle, DateTime>(
                      dataSource: stock.candleHistory,
                      xValueMapper: (data, _) => data.date,
                      yValueMapper: (data, _) => data.volume,
                      yAxisName: 'VolumeAxis',
                      pointColorMapper: (data, _) => data.close >= data.open ? AppColors.profit.withValues(alpha: 0.5) : AppColors.loss.withValues(alpha: 0.5),
                    ),
                    CandleSeries<StockCandle, DateTime>(
                      dataSource: stock.candleHistory,
                      xValueMapper: (data, _) => data.date,
                      lowValueMapper: (data, _) => data.low,
                      highValueMapper: (data, _) => data.high,
                      openValueMapper: (data, _) => data.open,
                      closeValueMapper: (data, _) => data.close,
                      bearColor: AppColors.loss,
                      bullColor: AppColors.profit,
                      enableSolidCandles: true,
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 36,
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
                  child: Container(
                    alignment: Alignment.center,
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  ),
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
          );

          if (isDesktop) {
            return Container(
              color: const Color(0xFF0B0E11), // Global dark background
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        Expanded(flex: 6, child: _PanelCard(child: chartWidget)),
                        const SizedBox(height: 8),
                        Expanded(
                          flex: 4,
                          child: _PanelCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF2B3139)))),
                                  child: Row(
                                    children: [
                                      _buildTab(1, 'Positions (${userState.futuresPositions.length})'),
                                      _buildTab(2, 'Orders (0)'),
                                    ],
                                  ),
                                ),
                                Expanded(child: _buildPositionsTab(userState, market, formatter)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _PanelCard(
                      child: _buildOrderBookPanel(stock, formatter),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _PanelCard(
                      child: _buildTradeFormPanel(stock, userState, formatter),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              SizedBox(height: 300, child: chartWidget),
              Container(
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
                child: Row(
                  children: [
                    _buildTab(0, 'Trade'),
                    _buildTab(1, 'Positions (${userState.futuresPositions.length})'),
                    _buildTab(2, 'Orders (0)'),
                  ],
                ),
              ),
              Expanded(
                child: _selectedTab == 0 ? _buildTradeInterface(stock, userState, formatter) : _buildPositionsTab(userState, market, formatter),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTab(int index, String title) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isSelected ? AppColors.primary : Colors.transparent, width: 2)),
        ),
        child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.white54)),
      ),
    );
  }

  Widget _buildTradeInterface(Stock stock, UserState userState, AppCurrencyFormatter formatter) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 4, child: _buildOrderBookPanel(stock, formatter)),
        Expanded(flex: 5, child: _buildTradeFormPanel(stock, userState, formatter)),
      ],
    );
  }

  Widget _buildOrderBookPanel(Stock stock, AppCurrencyFormatter formatter) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Price', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text('Amount', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          // Asks (Red)
          ...List.generate(5, (i) {
            final price = stock.currentPrice * (1 + 0.0005 * (5 - i));
            final amount = (stock.volume * 0.01) * (1 + sin(i));
            return _buildOrderRow(price, amount, AppColors.loss, formatter, true);
          }),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Text(formatter.format(stock.currentPrice), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: stock.changePercentage >= 0 ? AppColors.profit : AppColors.loss)),
                const SizedBox(width: 8),
                Icon(stock.changePercentage >= 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: stock.changePercentage >= 0 ? AppColors.profit : AppColors.loss),
              ],
            ),
          ),
          // Bids (Green)
          ...List.generate(5, (i) {
            final price = stock.currentPrice * (1 - 0.0005 * (i + 1));
            final amount = (stock.volume * 0.01) * (1 + cos(i));
            return _buildOrderRow(price, amount, AppColors.profit, formatter, false);
          }),
        ],
      ),
    );
  }

  Widget _buildTradeFormPanel(Stock stock, UserState userState, AppCurrencyFormatter formatter) {
    final currSym = CurrencyFormatters.getSymbol(userState.profile.preferredCurrency);
    final marginRequired = (_quantity > 0) ? (_quantity * stock.currentPrice) / _leverage : 0.0;
    final canExecute = _quantity > 0 && marginRequired <= userState.profile.virtualBalance;
    final isLong = _side == OrderSide.buy;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Long / Short Toggle
            Container(
              decoration: BoxDecoration(color: const Color(0xFF0B0E11), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _side = OrderSide.buy),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isLong ? const Color(0xFF2B3139) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text('Long', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isLong ? AppColors.profit : Colors.white54)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _side = OrderSide.sell),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isLong ? const Color(0xFF2B3139) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text('Short', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: !isLong ? AppColors.loss : Colors.white54)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Market / Leverage Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFF2B3139), borderRadius: BorderRadius.circular(6)),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Market', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Icon(Icons.arrow_drop_down, size: 16)]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFF2B3139), borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${_leverage.toInt()}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const Icon(Icons.arrow_drop_down, size: 16)]),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Slider for Leverage
            SliderTheme(
              data: SliderThemeData(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 14)),
              child: Slider(
                value: _leverage,
                min: 1, max: 100,
                activeColor: AppColors.primary,
                inactiveColor: const Color(0xFF2B3139),
                onChanged: (v) => setState(() => _leverage = v),
              ),
            ),
            const SizedBox(height: 16),
            // Size Input Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isInrInput ? 'Size ($currSym)' : 'Size (${stock.symbol})',
                  style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _isInrInput = !_isInrInput;
                    _qtyController.clear();
                  }),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        _isInrInput ? 'Switch to ${stock.symbol}' : 'Switch to $currSym',
                        style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Size Input
            TextField(
              controller: _qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                hintText: _isInrInput ? 'Enter amount in $currSym' : 'Enter qty in ${stock.symbol}',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: isLong ? AppColors.profit : AppColors.loss, width: 1.5),
                ),
                filled: true,
                fillColor: const Color(0xFF2B3139),
                suffixText: _isInrInput ? currSym : stock.symbol,
                suffixStyle: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            // Preview
            if (_inputVal > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B3139).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _isInrInput
                            ? '≈ ${(_inputVal / stock.currentPrice).toStringAsFixed(6)} ${stock.symbol}'
                            : '≈ ${formatter.format(_inputVal * stock.currentPrice)}',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // Quick % buttons
            Row(
              children: [25, 50, 75, 100].map((pct) {
                final label = pct == 100 ? 'MAX' : '$pct%';
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _setPercent(pct / 100, userState.profile.virtualBalance, stock.currentPrice),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B3139),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Margin Required', style: TextStyle(fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 4),
                Text(
                  formatter.format(marginRequired),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available Balance', style: TextStyle(fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 4),
                Text(
                  formatter.format(userState.profile.virtualBalance),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: canExecute ? () {
                final success = ref.read(userProvider.notifier).openFuturesPosition(stock, _side, _leverage.toInt(), _quantity);
                if (success) {
                  _qtyController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Position opened successfully!'), backgroundColor: AppColors.profit));
                }
              } : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: isLong ? AppColors.profit : AppColors.loss,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(isLong ? 'Buy / Long' : 'Sell / Short', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderRow(double price, double amount, Color color, AppCurrencyFormatter formatter, bool isAsk) {
    return Container(
      height: 26,
      margin: const EdgeInsets.only(bottom: 2),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 40 + (amount % 80), // Simulated depth
              color: color.withValues(alpha: 0.15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(price.toStringAsFixed(2), style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
                Text('${(amount/1000).toStringAsFixed(2)}K', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionsTab(UserState userState, List<Stock> market, AppCurrencyFormatter formatter) {
    if (userState.futuresPositions.isEmpty) {
      return const Center(child: Text('No open positions.', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: userState.futuresPositions.length,
      itemBuilder: (context, index) {
        final pos = userState.futuresPositions[index];
        final stock = market.firstWhere((s) => s.symbol == pos.symbol, orElse: () => market.first);
        final isLong = pos.side == OrderSide.buy;
        final priceDiff = stock.currentPrice - pos.entryPrice;
        final pnl = isLong ? priceDiff * pos.quantity : -priceDiff * pos.quantity;
        final roe = (pnl / pos.margin) * 100;

        return FuturesPositionCard(
          pos: pos,
          stock: stock,
          pnl: pnl,
          roe: roe,
          isLong: isLong,
          formatter: formatter,
          onClose: () {
            ref.read(userProvider.notifier).closeFuturesPosition(pos, stock.currentPrice);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Position closed. P&L: ${pnl >= 0 ? '+' : ''}${formatter.format(pnl)}'),
                backgroundColor: pnl >= 0 ? AppColors.profit : AppColors.loss,
              ),
            );
          },
        );
      },
    );
  }
}

class _PanelCard extends StatelessWidget {
  final Widget child;
  const _PanelCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181A20), // Premium dark mode panel color
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2B3139), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}
