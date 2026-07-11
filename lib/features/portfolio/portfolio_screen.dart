import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../data/market_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../futures/futures_pro_screen.dart';
import '../stock_detail/stock_detail_screen.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final market = ref.watch(marketProvider);
    
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    double portfolioValue = 0;
    double investedValue = 0;
    
    // Map to hold distribution data for pie chart
    final Map<String, double> assetValues = {};
    
    for (final holding in userState.holdings) {
      final stock = market.firstWhere((s) => s.symbol == holding.symbol);
      final value = stock.currentPrice * holding.quantity;
      portfolioValue += value;
      investedValue += holding.averagePrice * holding.quantity;
      assetValues[holding.symbol] = value;
    }

    for (final pos in userState.futuresPositions) {
      final stock = market.firstWhere((s) => s.symbol == pos.symbol);
      final isLong = pos.side == OrderSide.buy;
      final priceDiff = stock.currentPrice - pos.entryPrice;
      final posPnl = isLong ? priceDiff * pos.quantity : -priceDiff * pos.quantity;
      
      final currentValue = pos.margin + posPnl;
      // We don't want negative asset value in the pie chart if they are about to be liquidated.
      final safeValue = currentValue > 0 ? currentValue : 0.0;
      
      portfolioValue += safeValue;
      investedValue += pos.margin;
      
      final assetKey = '${pos.symbol} (Futures)';
      assetValues[assetKey] = (assetValues[assetKey] ?? 0) + safeValue;
    }
    
    final cash = userState.profile.virtualBalance;
    final totalNetWorth = portfolioValue + cash;
    final pnl = portfolioValue - investedValue;
    final pnlPercent = investedValue == 0 ? 0.0 : (pnl / investedValue) * 100;
    
    assetValues['CASH'] = cash;

    // Generate Pie Chart Sections
    final colors = [
      AppColors.primary,
      const Color(0xFFF3BA2F), // Binance Yellow
      const Color(0xFF14F195), // Solana Green
      const Color(0xFF00C2FE), // Blue
      const Color(0xFF8247E5), // Purple
      const Color(0xFFEA3943), // Red
    ];
    
    final sortedAssets = assetValues.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    final pieSections = List.generate(sortedAssets.length, (i) {
      final isTouched = i == touchedIndex;
      final radius = isTouched ? 60.0 : 50.0;
      final asset = sortedAssets[i];
      final percentage = totalNetWorth == 0 ? 0 : (asset.value / totalNetWorth) * 100;
      
      return PieChartSectionData(
        color: colors[i % colors.length],
        value: asset.value,
        title: percentage > 5 ? '${percentage.toStringAsFixed(1)}%' : '',
        radius: radius,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Portfolio', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
            // Net Worth Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2329),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2B3139)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Net Worth', style: TextStyle(color: Color(0xFF848E9C), fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    formatter.format(totalNetWorth),
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Today\'s P&L', style: TextStyle(color: Color(0xFF848E9C), fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '${pnl >= 0 ? '+' : ''}${formatter.format(pnl)}',
                            style: TextStyle(
                              color: pnl >= 0 ? AppColors.profit : AppColors.loss,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Return %', style: TextStyle(color: Color(0xFF848E9C), fontSize: 12)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (pnl >= 0 ? AppColors.profit : AppColors.loss).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${pnl >= 0 ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: pnl >= 0 ? AppColors.profit : AppColors.loss,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Asset Allocation Chart
            if (totalNetWorth > 0) ...[
              const Text('Asset Allocation', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                  touchedIndex = -1;
                                  return;
                                }
                                touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: pieSections,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(min(5, sortedAssets.length), (index) {
                          final asset = sortedAssets[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: colors[index % colors.length])),
                                const SizedBox(width: 8),
                                Expanded(child: Text(asset.key, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Spot Holdings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 12),
                            if (userState.holdings.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(16)),
                                child: const Text('No active holdings. Go to Spot market to buy.', style: TextStyle(color: Color(0xFF848E9C))),
                              )
                            else
                              ...userState.holdings.map((h) {
                                final stock = market.firstWhere((s) => s.symbol == h.symbol);
                                final currentVal = stock.currentPrice * h.quantity;
                                final invested = h.averagePrice * h.quantity;
                                final returnVal = currentVal - invested;
                                final good = returnVal >= 0;
                                return InkWell(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailScreen(stockSymbol: stock.symbol))),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        CircleAvatar(backgroundColor: const Color(0xFF2B3139), child: Text(stock.symbol[0], style: const TextStyle(color: Colors.white))),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(stock.symbol, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                              const SizedBox(height: 2),
                                              Text('${h.quantity} qty', style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(formatter.format(currentVal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                            const SizedBox(height: 2),
                                            Text('${good ? '+' : ''}${formatter.format(returnVal)}', style: TextStyle(color: good ? AppColors.profit : AppColors.loss, fontWeight: FontWeight.w700, fontSize: 12)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Futures Positions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 12),
                            if (userState.futuresPositions.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(16)),
                                child: const Text('No open positions. Go to Futures market to trade.', style: TextStyle(color: Color(0xFF848E9C))),
                              )
                            else
                              ...userState.futuresPositions.map((pos) {
                                final stock = market.firstWhere((s) => s.symbol == pos.symbol);
                                final isLong = pos.side == OrderSide.buy;
                                final priceDiff = stock.currentPrice - pos.entryPrice;
                                final pnl = isLong ? priceDiff * pos.quantity : -priceDiff * pos.quantity;
                                final good = pnl >= 0;
                                final pnlPercent = (pnl / pos.margin) * 100;
                                
                                return InkWell(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FuturesProScreen(stockSymbol: stock.symbol))),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: (isLong ? AppColors.profit : AppColors.loss).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${pos.leverage}x',
                                            style: TextStyle(color: isLong ? AppColors.profit : AppColors.loss, fontSize: 10, fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(stock.symbol, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                              const SizedBox(height: 2),
                                              Text('Margin ${formatter.format(pos.margin)}', style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('${good ? '+' : ''}${formatter.format(pnl)}', style: TextStyle(color: good ? AppColors.profit : AppColors.loss, fontWeight: FontWeight.w800, fontSize: 16)),
                                            const SizedBox(height: 2),
                                            Text('${good ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%', style: TextStyle(color: good ? AppColors.profit : AppColors.loss, fontWeight: FontWeight.w700, fontSize: 12)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Recent Trades', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 12),
                            if (userState.trades.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(16)),
                                child: const Text('No trades yet.', style: TextStyle(color: Color(0xFF848E9C))),
                              )
                            else
                              ...userState.trades.take(10).map((t) {
                                final isBuy = t.side == OrderSide.buy;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: (isBuy ? AppColors.profit : AppColors.loss).withValues(alpha: 0.1), shape: BoxShape.circle),
                                        child: Icon(isBuy ? Icons.arrow_downward : Icons.arrow_upward, color: isBuy ? AppColors.profit : AppColors.loss, size: 16),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${isBuy ? "Buy" : "Sell"} ${t.symbol}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                
                // --- Mobile Layout ---
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Spot Holdings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    if (userState.holdings.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(16)),
                        child: const Text('No active holdings. Go to Spot market to buy.', style: TextStyle(color: Color(0xFF848E9C))),
                      )
                    else
                      ...userState.holdings.map((h) {
                        final stock = market.firstWhere((s) => s.symbol == h.symbol);
                        final currentVal = stock.currentPrice * h.quantity;
                        final invested = h.averagePrice * h.quantity;
                        final returnVal = currentVal - invested;
                        final good = returnVal >= 0;
                        return InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailScreen(stockSymbol: stock.symbol))),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                CircleAvatar(backgroundColor: const Color(0xFF2B3139), child: Text(stock.symbol[0], style: const TextStyle(color: Colors.white))),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(stock.symbol, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                      const SizedBox(height: 2),
                                      Text('${h.quantity} qty • Avg ${formatter.format(h.averagePrice)}', style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(formatter.format(currentVal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                    const SizedBox(height: 2),
                                    Text('${good ? '+' : ''}${formatter.format(returnVal)}', style: TextStyle(color: good ? AppColors.profit : AppColors.loss, fontWeight: FontWeight.w700, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      
                    const SizedBox(height: 24),
                    const Text('Futures Positions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    if (userState.futuresPositions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(16)),
                        child: const Text('No open positions. Go to Futures market to trade.', style: TextStyle(color: Color(0xFF848E9C))),
                      )
                    else
                      ...userState.futuresPositions.map((pos) {
                        final stock = market.firstWhere((s) => s.symbol == pos.symbol);
                        final isLong = pos.side == OrderSide.buy;
                        final priceDiff = stock.currentPrice - pos.entryPrice;
                        final pnl = isLong ? priceDiff * pos.quantity : -priceDiff * pos.quantity;
                        final good = pnl >= 0;
                        final pnlPercent = (pnl / pos.margin) * 100;
                        
                        return InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FuturesProScreen(stockSymbol: stock.symbol))),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isLong ? AppColors.profit : AppColors.loss).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${pos.leverage}x ${isLong ? 'Long' : 'Short'}',
                                    style: TextStyle(color: isLong ? AppColors.profit : AppColors.loss, fontSize: 10, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(stock.symbol, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                      const SizedBox(height: 2),
                                      Text('Margin ${formatter.format(pos.margin)} • Value ${formatter.format(pos.quantity * pos.entryPrice)}', style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${good ? '+' : ''}${formatter.format(pnl)}', style: TextStyle(color: good ? AppColors.profit : AppColors.loss, fontWeight: FontWeight.w800, fontSize: 16)),
                                    const SizedBox(height: 2),
                                    Text('${good ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%', style: TextStyle(color: good ? AppColors.profit : AppColors.loss, fontWeight: FontWeight.w700, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      
                    const SizedBox(height: 24),
                    const Text('Recent Trades', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    if (userState.trades.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(16)),
                        child: const Text('No trades yet.', style: TextStyle(color: Color(0xFF848E9C))),
                      )
                    else
                      ...userState.trades.take(10).map((t) {
                        final isBuy = t.side == OrderSide.buy;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: (isBuy ? AppColors.profit : AppColors.loss).withValues(alpha: 0.1), shape: BoxShape.circle),
                                child: Icon(isBuy ? Icons.arrow_downward : Icons.arrow_upward, color: isBuy ? AppColors.profit : AppColors.loss, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${isBuy ? "Buy" : "Sell"} ${t.symbol}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text('${t.time.day}/${t.time.month} ${t.time.hour}:${t.time.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Color(0xFF848E9C), fontSize: 11)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(formatter.format(t.price), style: const TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 2),
                                  Text('${t.quantity} qty', style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
          ),
        ),
      ),
    );
  }
}
