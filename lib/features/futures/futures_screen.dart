import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';


import '../../core/app_theme.dart';
import '../../core/coin_icon.dart';
import '../../core/currency_formatters.dart';
import '../../data/market_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import 'futures_pro_screen.dart';
import 'futures_position_card.dart';

class FuturesScreen extends ConsumerStatefulWidget {
  const FuturesScreen({super.key});

  @override
  ConsumerState<FuturesScreen> createState() => _FuturesScreenState();
}

class _FuturesScreenState extends ConsumerState<FuturesScreen> {
  String _query = '';
  String _filter = 'All';
  bool _showPositions = false;

  static const _categories = [
    'All', 'Layer 1', 'Layer 2', 'DeFi', 'Exchange',
    'Infrastructure', 'Payments', 'Gaming', 'AI', 'Meme',
  ];

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final market = ref.watch(marketProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    double totalUnrealizedPnl = 0;
    double totalMargin = 0;
    for (final pos in userState.futuresPositions) {
      final stock = market.firstWhere(
          (s) => s.symbol == pos.symbol, orElse: () => market.first);
      final isLong = pos.side == OrderSide.buy;
      final priceDiff = stock.currentPrice - pos.entryPrice;
      final pnl = isLong ? priceDiff * pos.quantity : -priceDiff * pos.quantity;
      totalUnrealizedPnl += pnl;
      totalMargin += pos.margin;
    }

    final filteredMarket = market.where((s) {
      final q = _query.toLowerCase();
      final matchesSearch = s.symbol.toLowerCase().contains(q) ||
          s.name.toLowerCase().contains(q);
      final matchesFilter = _filter == 'All' || s.category == _filter;
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E11),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── HEADER ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Futures',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Perpetual contracts · Up to 100x',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Toggle: Markets / Positions
                  if (MediaQuery.of(context).size.width <= 800)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2329),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF2B3139)),
                      ),
                      child: Row(
                        children: [
                          _TabToggle(
                            label: 'Markets',
                            selected: !_showPositions,
                            onTap: () => setState(() => _showPositions = false),
                          ),
                          _TabToggle(
                            label: 'Positions (${userState.futuresPositions.length})',
                            selected: _showPositions,
                            onTap: () => setState(() => _showPositions = true),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── PNL STRIP ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF141A21),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2B3139)),
                ),
                child: Row(
                  children: [
                    _PnlCell(
                      label: 'Unrealized P&L',
                      value: '${totalUnrealizedPnl >= 0 ? '+' : ''}${formatter.format(totalUnrealizedPnl)}',
                      valueColor: totalUnrealizedPnl >= 0
                          ? AppColors.profit
                          : totalUnrealizedPnl < 0
                              ? AppColors.loss
                              : const Color(0xFF6B7280),
                    ),
                    Container(width: 1, height: 30, color: const Color(0xFF2B3139), margin: const EdgeInsets.symmetric(horizontal: 12)),
                    _PnlCell(
                      label: 'Margin Used',
                      value: formatter.format(totalMargin),
                    ),
                    Container(width: 1, height: 30, color: const Color(0xFF2B3139), margin: const EdgeInsets.symmetric(horizontal: 12)),
                    _PnlCell(
                      label: 'Open Positions',
                      value: '${userState.futuresPositions.length}',
                    ),
                    Container(width: 1, height: 30, color: const Color(0xFF2B3139), margin: const EdgeInsets.symmetric(horizontal: 12)),
                    _PnlCell(
                      label: 'Balance',
                      value: formatter.format(userState.profile.virtualBalance),
                      valueColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  
                  final marketsWidget = Column(
                    children: [
                      // ── SEARCH ──────────────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                              hintText: 'Search contracts... BTC, ETH, SOL',
                              hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
                              prefixIcon: const Icon(Icons.search, color: Color(0xFF4B5563), size: 18),
                              filled: true,
                              fillColor: const Color(0xFF1E2329),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: Color(0xFF2B3139)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: Color(0xFF2B3139)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1),
                              ),
                            ),
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ),
                      ),

                      // ── CATEGORY FILTERS ────────────────────────────────────────
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                          scrollDirection: Axis.horizontal,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemCount: _categories.length,
                          itemBuilder: (_, i) {
                            final cat = _categories[i];
                            final selected = _filter == cat;
                            return GestureDetector(
                              onTap: () => setState(() => _filter = cat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : const Color(0xFF1E2329),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary.withValues(alpha: 0.6)
                                        : const Color(0xFF2B3139),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    color: selected ? AppColors.primary : const Color(0xFF6B7280),
                                    fontSize: 11,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // ── COLUMN HEADERS ──────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 5,
                              child: Text('CONTRACT',
                                  style: TextStyle(
                                      color: Color(0xFF4B5563),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                            ),
                            const Expanded(
                              flex: 4,
                              child: Text('PRICE',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      color: Color(0xFF4B5563),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                            ),
                            const SizedBox(
                              width: 70,
                              child: Text('24H %',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Color(0xFF4B5563),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                            ),
                            const SizedBox(
                              width: 48,
                              child: Text('LEV',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      color: Color(0xFF4B5563),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1, color: Color(0xFF1E2329)),

                      // ── MARKET CARDS ────────────────────────────────────────────
                      Expanded(
                        child: filteredMarket.isEmpty
                            ? const Center(
                                child: Text('No contracts found.',
                                    style: TextStyle(color: Color(0xFF6B7280))))
                            : ListView.separated(
                                physics: const ClampingScrollPhysics(),
                                itemCount: filteredMarket.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1, color: Color(0xFF1E2329)),
                                itemBuilder: (_, i) => _ContractCard(
                                  stock: filteredMarket[i],
                                  formatter: formatter,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FuturesProScreen(
                                          stockSymbol: filteredMarket[i].symbol),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );

                  final positionsWidget = Column(
                    children: [
                      // ── OPEN POSITIONS ──────────────────────────────────────────
                      Expanded(
                        child: userState.futuresPositions.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.inbox_outlined,
                                        color: Color(0xFF2B3139), size: 48),
                                    const SizedBox(height: 12),
                                    const Text('No open positions',
                                        style: TextStyle(
                                            color: Color(0xFF6B7280), fontSize: 14)),
                                    const SizedBox(height: 6),
                                    const Text('Open a contract to start trading',
                                        style: TextStyle(
                                            color: Color(0xFF4B5563), fontSize: 12)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                physics: const ClampingScrollPhysics(),
                                itemCount: userState.futuresPositions.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final pos = userState.futuresPositions[i];
                                  final stock = market.firstWhere(
                                      (s) => s.symbol == pos.symbol,
                                      orElse: () => market.first);
                                  final isLong = pos.side == OrderSide.buy;
                                  final priceDiff =
                                      stock.currentPrice - pos.entryPrice;
                                  final pnl = isLong
                                      ? priceDiff * pos.quantity
                                      : -priceDiff * pos.quantity;
                                  final roe = (pnl / pos.margin) * 100;

                                  return FuturesPositionCard(
                                    pos: pos,
                                    stock: stock,
                                    pnl: pnl,
                                    roe: roe,
                                    isLong: isLong,
                                    formatter: formatter,
                                    onClose: () {
                                      ref
                                          .read(userProvider.notifier)
                                          .closeFuturesPosition(
                                              pos, stock.currentPrice);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Position closed'),
                                          backgroundColor: AppColors.primary,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: marketsWidget),
                        Container(width: 1, color: const Color(0xFF2B3139)),
                        Expanded(flex: 2, child: positionsWidget),
                      ],
                    );
                  }

                  return _showPositions ? positionsWidget : marketsWidget;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB TOGGLE
// ─────────────────────────────────────────────────────────────────────────────
class _TabToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : const Color(0xFF6B7280),
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PNL CELL
// ─────────────────────────────────────────────────────────────────────────────
class _PnlCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _PnlCell({required this.label, required this.value, this.valueColor});

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
// CONTRACT CARD (row in the market list)
// ─────────────────────────────────────────────────────────────────────────────
class _ContractCard extends StatelessWidget {
  final Stock stock;
  final AppCurrencyFormatter formatter;
  final VoidCallback onTap;

  const _ContractCard({
    required this.stock,
    required this.formatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final good = stock.changePercentage >= 0;
    final pctColor = good ? AppColors.profit : AppColors.loss;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withValues(alpha: 0.02),
      highlightColor: Colors.white.withValues(alpha: 0.01),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // ── Symbol + name ──────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  // Icon box
                  CoinIcon(symbol: stock.symbol, size: 36),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              stock.symbol,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1F28),
                                border: Border.all(
                                    color: const Color(0xFF2B3139)),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'PERP',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
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

            // ── Price ──────────────────────────────────────────────────
            Expanded(
              flex: 4,
              child: stock.currentPrice == 0
                  ? const Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.primary,
                        ),
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
                          fontSize: 13,
                        ),
                      ),
                    ),
            ),

            // ── 24h % ──────────────────────────────────────────────────
            SizedBox(
              width: 70,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: pctColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    stock.currentPrice == 0
                        ? '—'
                        : '${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: stock.currentPrice == 0
                          ? const Color(0xFF6B7280)
                          : pctColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

            // ── Leverage ───────────────────────────────────────────────
            const SizedBox(
              width: 48,
              child: Text(
                '100x',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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
// POSITION CARD
