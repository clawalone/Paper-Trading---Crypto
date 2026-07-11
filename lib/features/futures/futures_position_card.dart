import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/coin_icon.dart';
import '../../core/currency_formatters.dart';
import '../../data/models.dart';

class FuturesPositionCard extends StatelessWidget {
  final FuturesPosition pos;
  final Stock stock;
  final double pnl;
  final double roe;
  final bool isLong;
  final AppCurrencyFormatter formatter;
  final VoidCallback onClose;

  const FuturesPositionCard({
    super.key,
    required this.pos,
    required this.stock,
    required this.pnl,
    required this.roe,
    required this.isLong,
    required this.formatter,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final pnlColor  = pnl >= 0 ? AppColors.profit : AppColors.loss;
    final sideColor = isLong ? AppColors.profit : AppColors.loss;

    final positionSize  = pos.quantity * pos.entryPrice;          // full leveraged value
    final currentValue  = pos.quantity * stock.currentPrice;       // current mark value
    final liqPrice      = pos.liquidationPrice;

    // Distance to liquidation as a %
    final distToLiq = liqPrice > 0
        ? ((stock.currentPrice - liqPrice) / stock.currentPrice * 100).abs()
        : 0.0;
    final liqColor = distToLiq < 5
        ? AppColors.loss
        : distToLiq < 15
            ? AppColors.warning
            : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141A21),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pnl >= 0
              ? AppColors.profit.withValues(alpha: 0.25)
              : AppColors.loss.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          // ── TOP HEADER ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                // Coin icon
                CoinIcon(symbol: pos.symbol, size: 34),
                const SizedBox(width: 10),

                // Symbol + side badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${pos.symbol}/INR',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: sideColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: sideColor.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              '${isLong ? 'LONG' : 'SHORT'} ${pos.leverage}x',
                              style: TextStyle(
                                  color: sideColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Perpetual Contract',
                        style: TextStyle(
                            color: Color(0xFF4B5563), fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // Live PnL
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${pnl >= 0 ? '+' : ''}${formatter.format(pnl)}',
                      style: TextStyle(
                          color: pnlColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: pnlColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ROE ${roe >= 0 ? '+' : ''}${roe.toStringAsFixed(2)}%',
                        style: TextStyle(
                            color: pnlColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF1E2329)),

          // ── STATS GRID ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              children: [
                // Row 1
                Row(
                  children: [
                    _Stat(
                      label: 'Margin',
                      value: formatter.format(pos.margin),
                      valueColor: Colors.white,
                    ),
                    _Stat(
                      label: 'Position Size',
                      value: formatter.format(positionSize),
                      valueColor: AppColors.primary,
                      align: CrossAxisAlignment.center,
                    ),
                    _Stat(
                      label: 'Current Value',
                      value: formatter.format(currentValue),
                      align: CrossAxisAlignment.end,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Row 2
                Row(
                  children: [
                    _Stat(
                      label: 'Entry Price',
                      value: formatter.format(pos.entryPrice),
                    ),
                    _Stat(
                      label: 'Mark Price',
                      value: formatter.format(stock.currentPrice),
                      valueColor: stock.currentPrice >= pos.entryPrice
                          ? AppColors.profit
                          : AppColors.loss,
                      align: CrossAxisAlignment.center,
                    ),
                    _Stat(
                      label: 'Qty (${pos.symbol})',
                      value: pos.quantity.toStringAsFixed(4),
                      align: CrossAxisAlignment.end,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── LIQUIDATION BAR ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: liqColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: liqColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: liqColor, size: 14),
                  const SizedBox(width: 6),
                  const Text('Liquidation Price:  ',
                      style: TextStyle(
                          color: Color(0xFF6B7280), fontSize: 11)),
                  Text(
                    formatter.format(liqPrice),
                    style: TextStyle(
                        color: liqColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    '${distToLiq.toStringAsFixed(1)}% away',
                    style: TextStyle(
                        color: liqColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          // ── CLOSE BUTTON ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: GestureDetector(
              onTap: () => _confirmClose(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2329),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2B3139)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_rounded,
                        color: AppColors.loss, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'Close Position  •  ${pnl >= 0 ? '+' : ''}${formatter.format(pnl)} P&L',
                      style: TextStyle(
                        color: pnlColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClose(BuildContext context) {
    final pnlColor = pnl >= 0 ? AppColors.profit : AppColors.loss;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2329),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Close Position?',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              '${pos.symbol} ${isLong ? 'Long' : 'Short'} ${pos.leverage}x',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: pnlColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pnlColor.withValues(alpha: 0.2))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(children: [
                    const Text('Margin',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(formatter.format(pos.margin),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ]),
                  Column(children: [
                    const Text('P&L',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      '${pnl >= 0 ? '+' : ''}${formatter.format(pnl)}',
                      style: TextStyle(
                          color: pnlColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 15),
                    ),
                  ]),
                  Column(children: [
                    const Text('You Receive',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      formatter.format((pos.margin + pnl).clamp(0, double.infinity)),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF2B3139)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white60)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onClose();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.loss,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Confirm Close',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final CrossAxisAlignment align;

  const _Stat(
      {required this.label,
      required this.value,
      this.valueColor,
      this.align = CrossAxisAlignment.start});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
