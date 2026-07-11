import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../../data/market_provider.dart';

class RequestMoneyScreen extends ConsumerStatefulWidget {
  const RequestMoneyScreen({super.key});

  @override
  ConsumerState<RequestMoneyScreen> createState() => _RequestMoneyScreenState();
}

class _RequestMoneyScreenState extends ConsumerState<RequestMoneyScreen> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  double _calculateNetWorth(UserState userState, List<Stock> stocks) {
    double portfolioValue = 0;
    for (var h in userState.holdings) {
      final stock = stocks.firstWhere(
        (c) => c.symbol == h.symbol,
        orElse: () => stocks.first,
      );
      portfolioValue += h.quantity * stock.currentPrice;
    }

    double futuresValue = 0;
    for (final pos in userState.futuresPositions) {
      final s = stocks.firstWhere((m) => m.symbol == pos.symbol,
          orElse: () => stocks.first);
      final isLong = pos.side == OrderSide.buy;
      final diff = s.currentPrice - pos.entryPrice;
      final pnl = isLong ? diff * pos.quantity : -diff * pos.quantity;
      final currentValue = pos.margin + pnl;
      futuresValue += currentValue > 0 ? currentValue : 0;
    }

    return userState.profile.virtualBalance + portfolioValue + futuresValue;
  }

  Future<void> _submitRequest() async {
    final amountStr = _amountController.text.trim();
    final reason = _reasonController.text.trim();

    if (amountStr.isEmpty || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount')));
      return;
    }

    if (amount > 100000) {
      final currSym = CurrencyFormatters.getSymbol(ref.read(userProvider).profile.preferredCurrency);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot request more than $currSym 1,00,000')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userState = ref.read(userProvider);
    final marketState = ref.read(marketProvider);
    final netWorth = _calculateNetWorth(userState, marketState);

    setState(() => _isSubmitting = true);

    try {
      // Calculate how many requests this month
      final qs = await FirebaseFirestore.instance
          .collection('money_requests')
          .where('requesterId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();
      
      final now = DateTime.now();
      int monthCount = 0;
      for (var doc in qs.docs) {
        final r = MoneyRequest.fromJson(doc.data() as Map<String, dynamic>);
        if (r.createdAt != null && r.createdAt!.year == now.year && r.createdAt!.month == now.month) {
          monthCount++;
        }
      }

      if (monthCount >= 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have reached the limit of 5 requests per month.')));
          setState(() => _isSubmitting = false);
        }
        return;
      }

      final finalReason = '$reason (Request ${monthCount + 1}/5 this month)';

      final docRef = FirebaseFirestore.instance.collection('money_requests').doc();
      final request = MoneyRequest(
        id: docRef.id,
        requesterUid: userState.profile.publicUid,
        requesterId: user.uid,
        amount: amount,
        reason: finalReason,
        requesterNetWorth: netWorth,
        status: 'pending',
        createdAt: now,
      );

      await docRef.set(request.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request submitted successfully!')));
        _amountController.clear();
        _reasonController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final user = FirebaseAuth.instance.currentUser;
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    final currSym = CurrencyFormatters.getSymbol(userState.profile.preferredCurrency);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E11),
        elevation: 0,
        title: const Text('Request Funds', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Submit Form
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Need more virtual funds?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('You can request up to $currSym 1,00,00,000 from the admin. Limit: 5 requests per month. Please provide a valid reason.', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Amount (Max $currSym 1,00,00,000)',
                      labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                      filled: true,
                      fillColor: const Color(0xFF141A21),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(currSym, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reasonController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Reason for request',
                      labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                      filled: true,
                      fillColor: const Color(0xFF141A21),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Text('Submit Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2B3139), thickness: 1, height: 1),
            // History
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Your Requests', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            Expanded(
              child: user == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('money_requests')
                          .where('requesterId', isEqualTo: user.uid)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error loading requests', style: TextStyle(color: AppColors.loss)));
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text('No requests yet', style: TextStyle(color: Color(0xFF6B7280))),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final req = MoneyRequest.fromJson(docs[index].data() as Map<String, dynamic>);
                            Color statusColor;
                            IconData statusIcon;
                            if (req.status == 'approved') {
                              statusColor = AppColors.profit;
                              statusIcon = Icons.check_circle;
                            } else if (req.status == 'rejected') {
                              statusColor = AppColors.loss;
                              statusIcon = Icons.cancel;
                            } else {
                              statusColor = AppColors.warning;
                              statusIcon = Icons.hourglass_empty;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141A21),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF2B3139)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        formatter.format(req.amount),
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      Row(
                                        children: [
                                          Icon(statusIcon, color: statusColor, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            req.status.toUpperCase(),
                                            style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Reason: ${req.reason}',
                                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                                  ),
                                  if (req.adminMessage != null && req.adminMessage!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.message, color: statusColor, size: 14),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Admin: ${req.adminMessage}',
                                              style: TextStyle(color: statusColor, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (req.status == 'approved') ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.profit.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.add_circle, color: AppColors.profit, size: 16),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Money Added: ${formatter.format(req.amount)}',
                                                style: const TextStyle(color: AppColors.profit, fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                            ],
                                          ),
                                          if (req.previousBalance != null && req.newBalance != null) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text('Previous Balance:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                                Text(formatter.format(req.previousBalance), style: const TextStyle(color: Colors.white, fontSize: 13)),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text('New Balance:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                                Text(formatter.format(req.newBalance), style: const TextStyle(color: AppColors.profit, fontSize: 13, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
