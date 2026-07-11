import 'dart:math';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_theme.dart';
import '../../core/coin_icon.dart';
import '../../core/currency_formatters.dart';
import '../../data/market_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../futures/futures_pro_screen.dart';
import '../profile/profile_screen.dart';
import '../stock_detail/stock_detail_screen.dart';
import '../rewards/rewards_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final market = ref.watch(marketProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    final isMarketLoading = market.isEmpty || market.first.currentPrice == 0;
    final isAppLoading = userState.isLoading || isMarketLoading;

    double portfolioValue = 0;
    double investedValue = 0;
    if (!isMarketLoading) {
      for (final h in userState.holdings) {
        final s = market.firstWhere((m) => m.symbol == h.symbol);
        portfolioValue += s.currentPrice * h.quantity;
        investedValue += h.averagePrice * h.quantity;
      }
    }

    double futuresPnl = 0;
    double futuresInvested = 0;
    double futuresValue = 0;
    if (!isMarketLoading) {
      for (final pos in userState.futuresPositions) {
        final s = market.firstWhere((m) => m.symbol == pos.symbol,
            orElse: () => market.first);
        final isLong = pos.side == OrderSide.buy;
        final diff = s.currentPrice - pos.entryPrice;
        final pnl = isLong ? diff * pos.quantity : -diff * pos.quantity;
        futuresPnl += pnl;
        futuresInvested += (pos.quantity * pos.entryPrice);
        final currentValue = pos.margin + pnl;
        futuresValue += currentValue > 0 ? currentValue : 0;
      }
    }

    final totalNetWorth = userState.profile.virtualBalance + portfolioValue + futuresValue;
    final todayPnl = (portfolioValue - investedValue) + futuresPnl;

    final gainers = List.of(market)
      ..sort((a, b) => b.changePercentage.compareTo(a.changePercentage));
    final losers = List.of(market)
      ..sort((a, b) => a.changePercentage.compareTo(b.changePercentage));
    final watchlist = userState.profile.watchlist.toList();
    final level = (userState.profile.xp ~/ 250) + 1;
    final hasUnclaimedRewards = !userState.hasClaimedDaily || userState.missions.any((m) => m.progress >= m.target && !userState.profile.completedMissions.contains(m.id));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E11),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              physics: const ClampingScrollPhysics(),
              children: [

            // ── TOP BAR ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E2329),
                            shape: BoxShape.circle,
                          ),
                          child: userState.profile.photoUrl.isNotEmpty
                              ? ClipOval(child: Image.network(userState.profile.photoUrl, fit: BoxFit.cover))
                              : Center(
                                  child: Text(
                                    userState.profile.name.isNotEmpty
                                        ? userState.profile.name[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userState.profile.name.split(' ').first,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                            TopRankBadge(userName: userState.profile.name),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsScreen())),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3BA2F).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.emoji_events, color: Color(0xFFF3BA2F), size: 12),
                              SizedBox(width: 4),
                              Text('Rewards', style: TextStyle(color: Color(0xFFF3BA2F), fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        if (hasUnclaimedRewards)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.loss,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2329),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.profit,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Live',
                          style: TextStyle(
                              color: AppColors.profit,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── MAIN CONTENT (LayoutBuilder for responsiveness) ────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;

                final portfolioWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── PORTFOLIO SUMMARY ────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NET WORTH',
                            style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1),
                          ),
                          const SizedBox(height: 6),
                          BlurLoader(
                            isLoading: isAppLoading,
                            child: Text(
                              formatter.format(totalNetWorth),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                todayPnl >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                color: todayPnl >= 0 ? AppColors.profit : AppColors.loss,
                                size: 18,
                              ),
                              Text(
                                '${todayPnl >= 0 ? '+' : ''}${formatter.format(todayPnl)} today',
                                style: TextStyle(
                                  color: todayPnl >= 0 ? AppColors.profit : AppColors.loss,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── 3-COL STATS ROW ──────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          _StatCell(
                            label: 'Cash',
                            value: formatter.format(userState.profile.virtualBalance),
                            isLoading: isAppLoading,
                          ),
                          _divider(),
                          _StatCell(
                            label: 'Spot Value',
                            value: formatter.format(portfolioValue),
                            isLoading: isAppLoading,
                          ),
                          _divider(),
                          _StatCell(
                            label: 'Futures Value',
                            value: formatter.format(futuresValue),
                            isLoading: isAppLoading,
                          ),
                        ],
                      ),
                    ),

                    const _Divider(),

                    // ── XP BAR ──────────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2329),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'Lv $level',
                              style: const TextStyle(
                                  color: Color(0xFFF0B90B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: (userState.profile.xp % 250) / 250,
                                minHeight: 4,
                                backgroundColor: const Color(0xFF1E2329),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFF0B90B)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${userState.profile.xp} XP',
                            style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 3),
                              Text(
                                '${userState.profile.streak}d',
                                style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final marketWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── MARKET TABLE: GAINERS ─────────────────────────────────────────
                    _SectionHeader(
                      title: 'Top Gainers',
                      onTap: null,
                    ),
                    _MarketTable(
                      stocks: gainers.take(5).toList(),
                      formatter: formatter,
                      onTap: (s) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StockDetailScreen(stockSymbol: s.symbol),
                        ),
                      ),
                    ),

                    const _Divider(),

                    // ── MARKET TABLE: LOSERS ──────────────────────────────────────────
                    _SectionHeader(
                      title: 'Top Losers',
                      onTap: null,
                    ),
                    _MarketTable(
                      stocks: losers.take(5).toList(),
                      formatter: formatter,
                      onTap: (s) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StockDetailScreen(stockSymbol: s.symbol),
                        ),
                      ),
                    ),

                    const _Divider(),

                    // ── FUTURES OVERVIEW ──────────────────────────────────────────────
                    _SectionHeader(title: 'Futures Markets', onTap: null),
                    // Positions summary strip
                    if (userState.futuresPositions.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141A21),
                            border: Border.all(color: const Color(0xFF2B3139)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              _InlineLabel(
                                label: 'Open Positions',
                                value: '${userState.futuresPositions.length}',
                              ),
                              _vDivider(),
                              _InlineLabel(
                                label: 'Total Invested',
                                value: formatter.format(futuresInvested),
                              ),
                              _vDivider(),
                              _InlineLabel(
                                label: 'Unrealized P&L',
                                value: '${futuresPnl >= 0 ? '+' : ''}${formatter.format(futuresPnl)}',
                                valueColor: futuresPnl >= 0 ? AppColors.profit : AppColors.loss,
                              ),
                            ],
                          ),
                        ),
                      ),
                      _SectionHeader(title: 'Futures Holdings', onTap: null),
                      ...userState.futuresPositions.map((pos) {
                        final stock = market.firstWhere((s) => s.symbol == pos.symbol, orElse: () => market.first);
                        final isLong = pos.side == OrderSide.buy;
                        final diff = stock.currentPrice - pos.entryPrice;
                        final pnl = isLong ? diff * pos.quantity : -diff * pos.quantity;
                        final isProfit = pnl >= 0;

                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF141A21), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF2B3139))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(color: (isLong ? AppColors.profit : AppColors.loss).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                        child: Text(isLong ? 'LONG ${pos.leverage}x' : 'SHORT ${pos.leverage}x', style: TextStyle(color: isLong ? AppColors.profit : AppColors.loss, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${pos.symbol} PERP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Invested: ${formatter.format(pos.quantity * pos.entryPrice)}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(formatter.format(pos.margin + pnl > 0 ? pos.margin + pnl : 0), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('${isProfit ? '+' : ''}${formatter.format(pnl)}', style: TextStyle(color: isProfit ? AppColors.profit : AppColors.loss, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                    _FuturesTable(
                      stocks: market.take(6).toList(),
                      formatter: formatter,
                      onTap: (s) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FuturesProScreen(stockSymbol: s.symbol),
                        ),
                      ),
                    ),
                  ],
                );

                if (isWide) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: portfolioWidget),
                        const SizedBox(width: 16),
                        Container(width: 1, height: 600, color: const Color(0xFF2B3139)), // Divider
                        const SizedBox(width: 16),
                        Expanded(flex: 6, child: marketWidget),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    portfolioWidget,
                    const _Divider(),
                    marketWidget,
                  ],
                );
              },
            ),

            const _Divider(),

            // ── ACTIVE QUESTS ────────────────────────────────────────────────
            if (userState.missions.isNotEmpty) ...[
              _SectionHeader(title: 'Active Quests', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsScreen()))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: userState.missions.take(2).map((m) {
                    final safeTarget = m.target <= 0 ? 1 : m.target;
                    final progress = (m.progress / safeTarget).clamp(0.0, 1.0);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: m.completed
                            ? AppColors.profit.withValues(alpha: 0.06)
                            : const Color(0xFF1E2329),
                        borderRadius: BorderRadius.circular(12),
                        border: m.completed
                            ? Border.all(color: AppColors.profit.withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.title,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                if (!m.completed) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 4,
                                      backgroundColor: const Color(0xFF2B3139),
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${m.progress}/${m.target} • +${m.reward} XP',
                                      style: const TextStyle(
                                          color: Color(0xFF6B7280), fontSize: 11)),
                                ] else
                                  Text('Completed! +${m.reward} XP',
                                      style: TextStyle(
                                          color: AppColors.profit,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (m.completed)
                            GestureDetector(
                              onTap: () => ref.read(userProvider.notifier).claimMission(m.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFF3BA2F), Color(0xFFE0A800)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFF3BA2F).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    )
                                  ],
                                ),
                                child: const Text('Claim!',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12)),
                              ),
                            )
                          else
                            Text('+${m.reward} XP',
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const _Divider(),
            ],

            // ── WATCHLIST ─────────────────────────────────────────────────────
            if (watchlist.isNotEmpty) ...[
              _SectionHeader(title: 'Watchlist', onTap: null),
              _MarketTable(
                stocks: watchlist
                    .map((sym) => market.firstWhere((s) => s.symbol == sym,
                        orElse: () => market.first))
                    .toList(),
                formatter: formatter,
                onTap: (s) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StockDetailScreen(stockSymbol: s.symbol),
                  ),
                ),
              ),
              const _Divider(),
            ],

            const SizedBox(height: 24),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: const Color(0xFF2B3139),
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );

  Widget _vDivider() => Container(
        width: 1,
        height: 28,
        color: const Color(0xFF2B3139),
        margin: const EdgeInsets.symmetric(horizontal: 10),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT CELL
// ─────────────────────────────────────────────────────────────────────────────
class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLoading;

  const _StatCell({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          BlurLoader(
            isLoading: isLoading,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE LABEL (for futures strip)
// ─────────────────────────────────────────────────────────────────────────────
class _InlineLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InlineLabel({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const _SectionHeader({required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: const Text(
                'View all',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HORIZONTAL DIVIDER
// ─────────────────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: const Color(0xFF1E2329),
      margin: const EdgeInsets.only(top: 16),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARKET TABLE — Zerodha-style compact rows with sparkline
// ─────────────────────────────────────────────────────────────────────────────
class _MarketTable extends StatelessWidget {
  final List<Stock> stocks;
  final AppCurrencyFormatter formatter;
  final void Function(Stock) onTap;

  const _MarketTable({
    required this.stocks,
    required this.formatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Column headers
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: const [
              Expanded(flex: 5, child: _ColHeader('SYMBOL')),
              Expanded(flex: 4, child: _ColHeader('PRICE', align: TextAlign.right)),
              SizedBox(width: 60, child: _ColHeader('CHART', align: TextAlign.center)),
              Expanded(flex: 3, child: _ColHeader('24H %', align: TextAlign.right)),
            ],
          ),
        ),
        ...stocks.map((s) => _MarketRow(
              stock: s,
              formatter: formatter,
              onTap: () => onTap(s),
            )),
      ],
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  final TextAlign align;

  const _ColHeader(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: const TextStyle(
          color: Color(0xFF4B5563), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    );
  }
}

class _MarketRow extends StatelessWidget {
  final Stock stock;
  final AppCurrencyFormatter formatter;
  final VoidCallback onTap;

  const _MarketRow({
    required this.stock,
    required this.formatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final good = stock.changePercentage >= 0;
    final color = good ? AppColors.profit : AppColors.loss;
    final hasHistory = stock.history.length >= 2;
    final spots = hasHistory
        ? stock.history.asMap().entries
            .map((e) => FlSpot(e.key.toDouble(), e.value))
            .toList()
        : <FlSpot>[];

    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withValues(alpha: 0.03),
      highlightColor: Colors.white.withValues(alpha: 0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Symbol
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  CoinIcon(symbol: stock.symbol, size: 32),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock.symbol,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          stock.name,
                          style: const TextStyle(
                              color: Color(0xFF4B5563), fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Price
            Expanded(
              flex: 4,
              child: stock.currentPrice == 0
                  ? const Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 10, height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.2, color: AppColors.primary),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatter.format(stock.currentPrice),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
            ),
            // Sparkline
            SizedBox(
              width: 60,
              height: 32,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: hasHistory
                    ? LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineTouchData: const LineTouchData(enabled: false),
                          minY: stock.history.reduce(min) * 0.995,
                          maxY: stock.history.reduce(max) * 1.005,
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: color,
                              barWidth: 1.2,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(show: false),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: Container(
                          height: 1,
                          color: const Color(0xFF2B3139),
                        ),
                      ),
              ),
            ),
            // % Change
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: stock.currentPrice == 0
                        ? const Color(0xFF1E2329)
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    stock.currentPrice == 0
                        ? '—'
                        : '${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                    style: TextStyle(
                        color: stock.currentPrice == 0
                            ? const Color(0xFF4B5563)
                            : color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FUTURES TABLE
// ─────────────────────────────────────────────────────────────────────────────
class _FuturesTable extends StatelessWidget {
  final List<Stock> stocks;
  final AppCurrencyFormatter formatter;
  final void Function(Stock) onTap;

  const _FuturesTable({
    required this.stocks,
    required this.formatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: const [
              Expanded(flex: 5, child: _ColHeader('CONTRACT')),
              Expanded(flex: 4, child: _ColHeader('PRICE', align: TextAlign.right)),
              Expanded(flex: 3, child: _ColHeader('24H %', align: TextAlign.right)),
              Expanded(flex: 2, child: _ColHeader('LEV', align: TextAlign.right)),
            ],
          ),
        ),
        ...stocks.map((s) => _FuturesRow(
              stock: s,
              formatter: formatter,
              onTap: () => onTap(s),
            )),
      ],
    );
  }
}

class _FuturesRow extends StatelessWidget {
  final Stock stock;
  final AppCurrencyFormatter formatter;
  final VoidCallback onTap;

  const _FuturesRow({
    required this.stock,
    required this.formatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final good = stock.changePercentage >= 0;
    final color = good ? AppColors.profit : AppColors.loss;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withValues(alpha: 0.03),
      highlightColor: Colors.white.withValues(alpha: 0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Contract name
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F28),
                      border: Border.all(color: const Color(0xFF2B3139)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'PERP',
                      style: TextStyle(
                          color: Color(0xFFF0B90B),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${stock.symbol}/INR',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Price
            Expanded(
              flex: 4,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatter.format(stock.currentPrice),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            // % Change
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            // Leverage
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '100x',
                  style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
class BlurLoader extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  
  const BlurLoader({super.key, required this.child, required this.isLoading});

  @override
  State<BlurLoader> createState() => _BlurLoaderState();
}

class _BlurLoaderState extends State<BlurLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + (_ctrl.value * 0.6),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class TopRankBadge extends ConsumerWidget {
  final String userName;
  const TopRankBadge({super.key, required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final market = ref.watch(marketProvider);
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final players = <Map<String, dynamic>>[];
        for (final doc in snapshot.data!.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            final state = UserState.fromJson(data);
            if (state.profile.email == 'admin@gmail.com' || state.profile.name.toLowerCase().contains('admin')) continue;
            
            double portfolioValue = 0;
            for (final holding in state.holdings) {
              try {
                final stock = market.firstWhere((s) => s.symbol == holding.symbol);
                portfolioValue += stock.currentPrice * holding.quantity;
              } catch(e) {
                portfolioValue += holding.averagePrice * holding.quantity;
              }
            }
            double futuresValue = 0;
            for (final pos in state.futuresPositions) {
              try {
                final stock = market.firstWhere((s) => s.symbol == pos.symbol);
                final isLong = pos.side == OrderSide.buy;
                final diff = stock.currentPrice - pos.entryPrice;
                final pnl = isLong ? diff * pos.quantity : -diff * pos.quantity;
                final currentValue = pos.margin + pnl;
                futuresValue += currentValue > 0 ? currentValue : 0;
              } catch(e) {
                futuresValue += pos.margin;
              }
            }
            players.add({
              'name': state.profile.name,
              'netWorth': state.profile.virtualBalance + portfolioValue + futuresValue,
            });
          } catch(e) {}
        }
        
        players.sort((a, b) => (b['netWorth'] as double).compareTo(a['netWorth'] as double));
        
        int rank = -1;
        for (int i = 0; i < players.length; i++) {
          if (players[i]['name'] == userName) {
            rank = i + 1;
            break;
          }
        }
        
        if (rank == 1) {
          return const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.emoji_events, color: Color(0xFFFBBF24), size: 16));
        } else if (rank == 2) {
          return const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.emoji_events, color: Color(0xFFE2E8F0), size: 16));
        } else if (rank == 3) {
          return const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.emoji_events, color: Color(0xFFF97316), size: 16));
        }
        return const SizedBox.shrink();
      },
    );
  }
}


