import 'dart:math';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/app_theme.dart';
import '../core/currency_formatters.dart';
import 'models.dart';

final userProvider = NotifierProvider<UserNotifier, UserState>(() {
  return UserNotifier();
});

class UserState {
  final bool isLoading;
  final bool isOnboarded;
  final UserProfile profile;
  final List<Holding> holdings;
  final List<Trade> trades;
  final List<Mission> missions;
  final List<FuturesPosition> futuresPositions;
  final List<Map<String, dynamic>> walletEntries;

  const UserState({
    this.isLoading = false,
    required this.isOnboarded,
    required this.profile,
    this.holdings = const [],
    this.trades = const [],
    required this.missions,
    this.futuresPositions = const [],
    this.walletEntries = const [],
  });

  UserState copyWith({
    bool? isLoading,
    bool? isOnboarded,
    UserProfile? profile,
    List<Holding>? holdings,
    List<Trade>? trades,
    List<Mission>? missions,
    List<FuturesPosition>? futuresPositions,
    List<Map<String, dynamic>>? walletEntries,
  }) {
    return UserState(
      isLoading: isLoading ?? this.isLoading,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      profile: profile ?? this.profile,
      holdings: holdings ?? this.holdings,
      trades: trades ?? this.trades,
      missions: missions ?? this.missions,
      futuresPositions: futuresPositions ?? this.futuresPositions,
      walletEntries: walletEntries ?? this.walletEntries,
    );
  }

  Map<String, dynamic> toJson() => {
    'isOnboarded': isOnboarded,
    'profile': profile.toJson(),
    'holdings': holdings.map((h) => h.toJson()).toList(),
    'trades': trades.map((t) => t.toJson()).toList(),
    'missions': missions.map((m) => m.toJson()).toList(),
    'futuresPositions': futuresPositions.map((f) => f.toJson()).toList(),
    'walletEntries': walletEntries,
  };

  factory UserState.fromJson(Map<String, dynamic> json) {
    final storedMissions = (json['missions'] as List?)?.map((m) => Mission.fromJson(m)).toList() ?? [];
    return UserState(
      isLoading: false,
      isOnboarded: json['isOnboarded'] as bool? ?? false,
      profile: json['profile'] != null ? UserProfile.fromJson(json['profile']) : const UserProfile(name: 'Guest', experienceLevel: 'Beginner', virtualBalance: 0, xp: 0, streak: 1, watchlist: {}),
      holdings: (json['holdings'] as List?)?.map((h) => Holding.fromJson(h)).toList() ?? [],
      trades: (json['trades'] as List?)?.map((t) => Trade.fromJson(t)).toList() ?? [],
      missions: storedMissions.isNotEmpty ? storedMissions : UserNotifier.MISSION_POOL.take(4).toList(),
      futuresPositions: (json['futuresPositions'] as List?)?.map((f) => FuturesPosition.fromJson(f)).toList() ?? [],
      walletEntries: (json['walletEntries'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
    );
  }

  bool get hasClaimedDaily {
    if (profile.lastDailyClaim == null || profile.lastDailyClaim!.isEmpty) return false;
    final lastClaim = DateTime.tryParse(profile.lastDailyClaim!);
    if (lastClaim == null) return false;
    final local = lastClaim.toLocal();
    final now = DateTime.now().toLocal();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }
}

class UserNotifier extends Notifier<UserState> {
  StreamSubscription? _sub;

  static const List<Mission> MISSION_POOL = [
    Mission(id: 'm1', title: 'Place your first virtual trade', reward: 100, target: 1),
    Mission(id: 'm2', title: 'Add 3 stocks to your watchlist', reward: 80, target: 3),
    Mission(id: 'm3', title: 'Finish the beginner quiz', reward: 120, target: 1),
    Mission(id: 'm4', title: 'Try both buy and sell orders', reward: 150, target: 2),
    Mission(id: 'm5', title: 'Make 5 total trades', reward: 200, target: 5),
    Mission(id: 'm6', title: 'Open your first futures position', reward: 200, target: 1),
    Mission(id: 'm7', title: 'Make 10 total trades', reward: 300, target: 10),
    Mission(id: 'm8', title: 'Add 5 stocks to your watchlist', reward: 150, target: 5),
    Mission(id: 'm9', title: 'Open 3 futures positions', reward: 400, target: 3),
    Mission(id: 'm10', title: 'Make 25 total trades', reward: 500, target: 25),
  ];

  @override
  UserState build() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _listenToFirestore(user);
      } else {
        _sub?.cancel();
        state = _defaultState();
      }
    });

    return _defaultState();
  }

  UserState _defaultState() {
    return UserState(
      isLoading: true,
      isOnboarded: false,
      profile: const UserProfile(
        name: 'Guest',
        experienceLevel: 'Beginner',
        virtualBalance: 0,
        xp: 0,
        streak: 1,
        watchlist: {},
      ),
      missions: MISSION_POOL.take(4).toList(),
    );
  }

  String _generateUid() {
    final rand = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'PT-$rand';
  }

  void _listenToFirestore(User user) {
    _sub?.cancel();
    _sub = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((doc) {
      if (doc.exists && doc.data() != null) {
        var profileState = UserState.fromJson(doc.data()!);
        bool needsUpdate = false;
        
        if (profileState.profile.publicUid.isEmpty) {
          profileState = profileState.copyWith(
            profile: profileState.profile.copyWith(publicUid: _generateUid())
          );
          needsUpdate = true;
        }
        
        if (profileState.profile.email != (user.email ?? '')) {
          profileState = profileState.copyWith(
            profile: profileState.profile.copyWith(email: user.email ?? '')
          );
          needsUpdate = true;
        }

        state = profileState;
        if (needsUpdate) {
          _saveToFirestore();
        }
      } else if (!doc.exists) {
        state = _defaultState().copyWith(
          isLoading: false,
          profile: _defaultState().profile.copyWith(
            name: user.displayName ?? '',
            publicUid: _generateUid(),
            email: user.email ?? '',
          )
        );
        _saveToFirestore();
      }
    });
  }

  Future<void> _saveToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(state.toJson());
    }
  }

  void _logWalletTx({
    required String title,
    required String subtitle,
    required double amount,
    required String type,
    required String category,
  }) {
    final entry = {
      'title': title,
      'subtitle': subtitle,
      'amount': amount,
      'type': type,
      'category': category,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final updated = List<Map<String, dynamic>>.from(state.walletEntries)..add(entry);
    state = state.copyWith(walletEntries: updated);
    _saveToFirestore();
  }

  void onboardUser(String name, String experienceLevel, String currency, String photoUrl) {
    state = state.copyWith(
      isOnboarded: true,
      profile: state.profile.copyWith(
        name: name.trim(),
        experienceLevel: experienceLevel,
        preferredCurrency: currency,
        photoUrl: photoUrl,
        virtualBalance: 100000,
        xp: 50,
      ),
    );
    _saveToFirestore();
  }

  void updateProfileSettings({String? name, String? currency, String? language, String? themeMode, String? photoUrl}) {
    state = state.copyWith(
      profile: state.profile.copyWith(
        name: name,
        preferredCurrency: currency,
        preferredLanguage: language,
        themeMode: themeMode,
        photoUrl: photoUrl,
      ),
    );
    _saveToFirestore();
  }

  void addFunds(double amount) {
    if (amount <= 0) return;
    state = state.copyWith(
      profile: state.profile.copyWith(
        virtualBalance: state.profile.virtualBalance + amount,
      ),
    );
    _saveToFirestore();
  }

  void toggleWatchlist(String symbol) {
    final current = Set<String>.from(state.profile.watchlist);
    if (current.contains(symbol)) {
      current.remove(symbol);
    } else {
      current.add(symbol);
      _addXp(10);
    }
    
    state = state.copyWith(profile: state.profile.copyWith(watchlist: current));
    _updateMissionProgress('m2', min(current.length, 3));
    _updateMissionProgress('m8', min(current.length, 5));
    _saveToFirestore();
  }

  void claimDailyReward() {
    if (state.hasClaimedDaily) return;

    final now = DateTime.now().toLocal();
    final todayStr = now.toIso8601String();
    
    int newStreak = 1;
    final lastClaimStr = state.profile.lastDailyClaim;
    if (lastClaimStr != null && lastClaimStr.isNotEmpty) {
      final lastClaim = DateTime.tryParse(lastClaimStr)?.toLocal();
      if (lastClaim != null) {
        final difference = DateTime(now.year, now.month, now.day)
            .difference(DateTime(lastClaim.year, lastClaim.month, lastClaim.day));
        if (difference.inDays == 1) {
          newStreak = state.profile.streak + 1;
        } else if (difference.inDays == 0) {
          newStreak = state.profile.streak;
        }
      }
    }

    state = state.copyWith(
      profile: state.profile.copyWith(
        virtualBalance: state.profile.virtualBalance + 1000,
        streak: newStreak,
        lastDailyClaim: todayStr,
      ),
    );
    _addXp(30);
    _saveToFirestore();
    _logWalletTx(
      title: 'Daily Check-In Reward',
      subtitle: 'Day $newStreak streak bonus',
      amount: 1000,
      type: 'credit',
      category: 'daily_reward',
    );
  }

  void recordQuizAttempt() {
    final now = DateTime.now().toIso8601String();
    state = state.copyWith(profile: state.profile.copyWith(lastQuizAttempt: now));
    _saveToFirestore();
  }

  void resetDailyReward() {
    state = state.copyWith(profile: state.profile.copyWith(lastDailyClaim: ''));
    _saveToFirestore();
  }

  void completeQuiz() {
    final m3Idx = state.missions.indexWhere((m) => m.id == 'm3');
    if (m3Idx >= 0) {
      _updateMissionProgress('m3', 1);
      _saveToFirestore();
    }
  }

  bool tradeStock(Stock stock, OrderSide side, int quantity) {
    if (quantity <= 0) return false;
    final totalCost = stock.currentPrice * quantity;
    final holdings = List<Holding>.from(state.holdings);
    
    if (side == OrderSide.buy) {
      if (state.profile.virtualBalance < totalCost) return false;
      final idx = holdings.indexWhere((h) => h.symbol == stock.symbol);
      if (idx >= 0) {
        final existing = holdings[idx];
        final newQty = existing.quantity + quantity;
        final newAvg = ((existing.quantity * existing.averagePrice) + totalCost) / newQty;
        holdings[idx] = Holding(symbol: stock.symbol, quantity: newQty, averagePrice: newAvg);
      } else {
        holdings.add(Holding(symbol: stock.symbol, quantity: quantity, averagePrice: stock.currentPrice));
      }
      state = state.copyWith(
        profile: state.profile.copyWith(virtualBalance: state.profile.virtualBalance - totalCost),
      );
    } else {
      final idx = holdings.indexWhere((h) => h.symbol == stock.symbol);
      if (idx < 0 || holdings[idx].quantity < quantity) return false;
      final existing = holdings[idx];
      state = state.copyWith(
        profile: state.profile.copyWith(virtualBalance: state.profile.virtualBalance + totalCost),
      );
      if (existing.quantity == quantity) {
        holdings.removeAt(idx);
      } else {
        holdings[idx] = Holding(symbol: stock.symbol, quantity: existing.quantity - quantity, averagePrice: existing.averagePrice);
      }
    }

    final newTrade = Trade(symbol: stock.symbol, side: side, quantity: quantity, price: stock.currentPrice, time: DateTime.now());
    state = state.copyWith(
      holdings: holdings,
      trades: [newTrade, ...state.trades],
    );

    _addXp(side == OrderSide.buy ? 35 : 45);
    _updateMissionProgress('m1', 1);
    _updateMissionProgress('m5', state.trades.length);
    _updateMissionProgress('m7', state.trades.length);
    _updateMissionProgress('m10', state.trades.length);
    
    final uniqueSides = state.trades.map((t) => t.side).toSet().length;
    _updateMissionProgress('m4', uniqueSides);

    _checkBadges();
    _saveToFirestore();
    return true;
  }

  bool openFuturesPosition(Stock stock, OrderSide side, int leverage, double quantity) {
    final marginRequired = (quantity * stock.currentPrice) / leverage;
    if (state.profile.virtualBalance < marginRequired) return false;

    final newPosition = FuturesPosition(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      symbol: stock.symbol,
      side: side,
      leverage: leverage,
      entryPrice: stock.currentPrice,
      quantity: quantity,
      margin: marginRequired,
    );

    _updateMissionProgress('m6', 1);
    _updateMissionProgress('m9', state.futuresPositions.length + 1);

    final newBalance = state.profile.virtualBalance - marginRequired;
    final newPositions = List<FuturesPosition>.from(state.futuresPositions)..add(newPosition);

    state = state.copyWith(
      profile: state.profile.copyWith(virtualBalance: newBalance),
      futuresPositions: newPositions,
    );

    // Log actual cash deducted (margin), show position size in subtitle
    final contractValue = quantity * stock.currentPrice; // = margin × leverage
    final formatter = AppCurrencyFormatter(state.profile.preferredCurrency);
    _logWalletTx(
      title: 'Futures Margin Deducted',
      subtitle: '${stock.symbol} ${side == OrderSide.buy ? 'Long' : 'Short'} ${leverage}x  •  Margin ${formatter.format(marginRequired)} × ${leverage} = Position ${formatter.format(contractValue)}',
      amount: marginRequired,
      type: 'debit',
      category: 'futures_open',
    );

    _saveToFirestore();
    return true;
  }

  void closeFuturesPosition(FuturesPosition position, double currentPrice) {
    final isLong = position.side == OrderSide.buy;
    final priceDiff = currentPrice - position.entryPrice;
    final pnl = isLong ? priceDiff * position.quantity : -priceDiff * position.quantity;
    
    final returnedAmount = position.margin + pnl;
    final safeReturn = returnedAmount > 0 ? returnedAmount : 0.0;
    final newBalance = state.profile.virtualBalance + safeReturn;
    
    final newPositions = state.futuresPositions.where((p) => p.id != position.id).toList();

    state = state.copyWith(
      profile: state.profile.copyWith(virtualBalance: newBalance),
      futuresPositions: newPositions,
    );

    final pnlSign = pnl >= 0 ? '+' : '';
    final dirLabel = '${position.symbol} ${isLong ? 'Long' : 'Short'} ${position.leverage}x';

    // Entry 1: margin returned to balance
    _logWalletTx(
      title: 'Futures Margin Returned',
      subtitle: '$dirLabel • Margin back to wallet',
      amount: position.margin,
      type: 'credit',
      category: 'futures_close',
    );

    // Entry 2: PnL (separate debit or credit)
    if (pnl != 0) {
      final formatter = AppCurrencyFormatter(state.profile.preferredCurrency);
      _logWalletTx(
        title: pnl >= 0 ? 'Futures Profit' : 'Futures Loss',
        subtitle: '$dirLabel • PnL: $pnlSign${formatter.format(pnl.abs())}',
        amount: pnl.abs(),
        type: pnl >= 0 ? 'credit' : 'debit',
        category: 'futures_pnl',
      );
    }

    _saveToFirestore();
  }

  void _addXp(int amount) {
    state = state.copyWith(
      profile: state.profile.copyWith(xp: state.profile.xp + amount),
    );
  }

  void _updateMissionProgress(String missionId, int progress) {
    final idx = state.missions.indexWhere((m) => m.id == missionId);
    if (idx < 0) return;
    
    final m = state.missions[idx];
    if (m.completed) return;

    final newProgress = max(m.progress, progress);
    final completed = newProgress >= m.target;
    
    final updatedMissions = List<Mission>.from(state.missions);
    updatedMissions[idx] = m.copyWith(progress: newProgress, completed: completed);
    state = state.copyWith(missions: updatedMissions);
  }

  void claimMission(String missionId) {
    final idx = state.missions.indexWhere((m) => m.id == missionId);
    if (idx < 0) return;
    
    final m = state.missions[idx];
    if (!m.completed) return;

    _addXp(m.reward);

    final completedSet = Set<String>.from(state.profile.completedMissions);
    completedSet.add(m.id);

    final updatedMissions = List<Mission>.from(state.missions);
    Mission? newMission;
    
    for (final poolM in MISSION_POOL) {
      if (!completedSet.contains(poolM.id) && !updatedMissions.any((active) => active.id == poolM.id)) {
        newMission = poolM;
        break;
      }
    }

    if (newMission != null) {
      updatedMissions[idx] = newMission;
    } else {
      updatedMissions.removeAt(idx);
    }

    state = state.copyWith(
      missions: updatedMissions,
      profile: state.profile.copyWith(completedMissions: completedSet)
    );
    _logWalletTx(
      title: 'Quest Reward',
      subtitle: m.title,
      amount: m.reward.toDouble(),
      type: 'credit',
      category: 'quest_reward',
    );
    _saveToFirestore();
  }

  void _checkBadges() {
    final currentBadges = Set<String>.from(state.profile.unlockedBadges);
    bool changed = false;

    if (state.trades.isNotEmpty && !currentBadges.contains('b1')) {
      currentBadges.add('b1');
      changed = true;
    }
    if (state.trades.length >= 10 && !currentBadges.contains('b2')) {
      currentBadges.add('b2');
      changed = true;
    }
    if (state.profile.virtualBalance > 20000000 && !currentBadges.contains('b3')) {
      currentBadges.add('b3');
      changed = true;
    }
    if (state.holdings.isNotEmpty && !currentBadges.contains('b4')) {
      currentBadges.add('b4');
      changed = true;
    }
    if (state.holdings.length >= 3 && !currentBadges.contains('b5')) {
      currentBadges.add('b5');
      changed = true;
    }

    if (changed) {
      state = state.copyWith(profile: state.profile.copyWith(unlockedBadges: currentBadges));
    }
  }
}
