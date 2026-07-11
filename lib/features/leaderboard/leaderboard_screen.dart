import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:animated_list_plus/animated_list_plus.dart';
import 'package:animated_list_plus/transitions.dart';

import '../../core/app_theme.dart';
import '../../data/user_provider.dart';
import '../../data/market_provider.dart';
import '../../core/currency_formatters.dart';
import '../../data/models.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final market = ref.watch(marketProvider);
    
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency, decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 70,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LEADERBOARD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Live Global Rankings',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading leaderboard.', style: TextStyle(color: AppColors.loss)));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            // Parse users and calculate live net worth
            final List<Map<String, dynamic>> players = [];
            
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
                  } catch (e) {
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
                    futuresValue += pos.margin; // fallback
                  }
                }
                
                final totalNetWorth = state.profile.virtualBalance + portfolioValue + futuresValue;
                
                players.add({
                  'uid': doc.id,
                  'name': state.profile.name,
                  'netWorth': totalNetWorth,
                  'xp': state.profile.xp,
                  'photoUrl': state.profile.photoUrl,
                });
              } catch (e) {
                // Skip invalid user documents
              }
            }

            // Sort by Net Worth (Descending)
            players.sort((a, b) => (b['netWorth'] as double).compareTo(a['netWorth'] as double));

            // Find current user's rank
            int myRank = -1;
            Map<String, dynamic>? myStats;
            for (int i = 0; i < players.length; i++) {
              if (players[i]['name'] == userState.profile.name) {
                myRank = i + 1;
                myStats = players[i];
                break;
              }
            }

            final nonPodiumPlayers = players.length > 3 ? players.sublist(3) : <Map<String, dynamic>>[];

            return Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _buildPodium(players, formatter),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 8, bottom: 100),
                          sliver: SliverToBoxAdapter(
                            child: ImplicitlyAnimatedList<Map<String, dynamic>>(
                              key: ValueKey(userState.profile.preferredCurrency),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              items: nonPodiumPlayers,
                              areItemsTheSame: (a, b) => a['uid'] == b['uid'],
                              itemBuilder: (context, animation, item, index) {
                                final rank = players.indexWhere((p) => p['uid'] == item['uid']) + 1;
                                return SizeFadeTransition(
                                  sizeFraction: 0.7,
                                  curve: Curves.easeInOut,
                                  animation: animation,
                                  child: _buildListPlayer(item, rank - 1, userState.profile.name, formatter),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (myStats != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildStickyUserBar(myStats, myRank, formatter),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> players, AppCurrencyFormatter formatter) {
    if (players.isEmpty) return const SizedBox();

    final top1 = players.isNotEmpty ? players[0] : null;
    final top2 = players.length > 1 ? players[1] : null;
    final top3 = players.length > 2 ? players[2] : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF13366A), Color(0xFF0F1722)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (top2 != null) _buildPodiumAvatar(top2, 2, const Color(0xFFE2E8F0), formatter),
          if (top1 != null) _buildPodiumAvatar(top1, 1, const Color(0xFFFBBF24), formatter),
          if (top3 != null) _buildPodiumAvatar(top3, 3, const Color(0xFFF97316), formatter),
        ],
      ),
    );
  }

  Widget _buildPodiumAvatar(Map<String, dynamic> player, int rank, Color color, AppCurrencyFormatter formatter) {
    final isTop1 = rank == 1;
    final radius = isTop1 ? 40.0 : 32.0;
    final hasPhoto = player['photoUrl'] != null && player['photoUrl'].toString().trim().isNotEmpty;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, color: color, size: isTop1 ? 20 : 16),
            const SizedBox(width: 4),
            Text(
              isTop1 ? '1st' : (rank == 2 ? '2nd' : '3rd'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFF2B3139),
            child: hasPhoto
                ? ClipOval(
                    child: Image.network(
                      player['photoUrl'],
                      width: radius * 2,
                      height: radius * 2,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Text(player['name'].toString().isNotEmpty ? player['name'].substring(0, 1).toUpperCase() : '?', style: TextStyle(color: Colors.white, fontSize: radius * 0.7, fontWeight: FontWeight.w600)),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Text(player['name'].toString().isNotEmpty ? player['name'].substring(0, 1).toUpperCase() : '?', style: TextStyle(color: Colors.white, fontSize: radius * 0.7, fontWeight: FontWeight.w600));
                      },
                    ),
                  )
                : Text(player['name'].toString().isNotEmpty ? player['name'].substring(0, 1).toUpperCase() : '?', style: TextStyle(color: Colors.white, fontSize: radius * 0.7, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          player['name'],
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: isTop1 ? 16 : 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${player['xp']} XP',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Text(
          formatter.format(player['netWorth']),
          style: const TextStyle(
            color: Color(0xFF06B6D4),
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildListPlayer(Map<String, dynamic> player, int index, String myName, AppCurrencyFormatter formatter) {
    final isMe = player['name'] == myName;
    final hasPhoto = player['photoUrl'] != null && player['photoUrl'].toString().trim().isNotEmpty;
    final rank = index + 1;
    final rankString = rank.toString().padLeft(2, '0');

    List<Color> edgeGradient;
    if (rank == 1) {
      edgeGradient = [const Color(0xFFFCD34D), const Color(0xFFD97706)];
    } else if (rank == 2) {
      edgeGradient = [const Color(0xFFA3E635), const Color(0xFF4D7C0F)];
    } else if (rank == 3) {
      edgeGradient = [const Color(0xFF67E8F9), const Color(0xFF0891B2)];
    } else {
      edgeGradient = [const Color(0xFF64748B), const Color(0xFF334155)];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 6,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: edgeGradient,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  child: Text(
                    rankString,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF2B3139),
                  child: hasPhoto 
                    ? ClipOval(
                        child: Image.network(
                          player['photoUrl'],
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Text(player['name'].toString().isNotEmpty ? player['name'].substring(0, 1).toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Text(player['name'].toString().isNotEmpty ? player['name'].substring(0, 1).toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600));
                          },
                        ),
                      )
                    : Text(player['name'].toString().isNotEmpty ? player['name'].substring(0, 1).toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              player['name'],
                              style: TextStyle(
                                color: isMe ? const Color(0xFF22C55E) : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (rank <= 3) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.emoji_events,
                              size: 16,
                              color: rank == 1 ? const Color(0xFFFBBF24) : (rank == 2 ? const Color(0xFFE2E8F0) : const Color(0xFFF97316)),
                            ),
                          ],
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                              child: const Text('YOU', style: TextStyle(color: Color(0xFF22C55E), fontSize: 10, fontWeight: FontWeight.w800)),
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${player['xp']} XP',
                        style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatter.format(player['netWorth']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyUserBar(Map<String, dynamic> myStats, int myRank, AppCurrencyFormatter formatter) {
    final hasPhoto = myStats['photoUrl'] != null && myStats['photoUrl'].toString().trim().isNotEmpty;
    final rankString = myRank.toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1722).withValues(alpha: 0.98),
        border: const Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              rankString,
              style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF2B3139),
            child: hasPhoto 
              ? ClipOval(
                  child: Image.network(
                    myStats['photoUrl'],
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Text(myStats['name'].toString().isNotEmpty ? myStats['name'].substring(0, 1).toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Text(myStats['name'].toString().isNotEmpty ? myStats['name'].substring(0, 1).toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600));
                    },
                  ),
                )
              : Text(myStats['name'].toString().isNotEmpty ? myStats['name'].substring(0, 1).toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        myStats['name'],
                        style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w700, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (myRank <= 3) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.emoji_events,
                        size: 16,
                        color: myRank == 1 ? const Color(0xFFFBBF24) : (myRank == 2 ? const Color(0xFFE2E8F0) : const Color(0xFFF97316)),
                      ),
                    ],
                    const SizedBox(width: 6),
                    const Text('YOUR RANK', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${myStats['xp']} XP',
                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Text(
            formatter.format(myStats['netWorth']),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
