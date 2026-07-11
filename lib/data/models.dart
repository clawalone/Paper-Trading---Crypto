class StockCandle {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const StockCandle({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}

class Stock {
  const Stock({
    required this.symbol,
    required this.name,
    required this.category,
    required this.currentPrice,
    required this.previousClose,
    required this.dayHigh,
    required this.dayLow,
    required this.volume,
    required this.history,
    required this.candleHistory,
    required this.about,
    required this.supply,
    required this.rank,
  });

  final String symbol;
  final String name;
  final String category;
  final double currentPrice;
  final double previousClose;
  final double dayHigh;
  final double dayLow;
  final int volume;
  final List<double> history;
  final List<StockCandle> candleHistory;
  final String about;
  final double supply;
  final int rank;

  double get change => currentPrice - previousClose;
  double get changePercentage => (change / previousClose) * 100;
  double get marketCap => currentPrice * supply;

  Stock copyWith({
    double? currentPrice,
    double? dayHigh,
    double? dayLow,
  }) {
    return Stock(
      symbol: symbol,
      name: name,
      category: category,
      currentPrice: currentPrice ?? this.currentPrice,
      previousClose: previousClose,
      dayHigh: dayHigh ?? this.dayHigh,
      dayLow: dayLow ?? this.dayLow,
      volume: volume,
      history: history,
      candleHistory: candleHistory,
      about: about,
      supply: supply,
      rank: rank,
    );
  }
}

class Holding {
  const Holding({
    required this.symbol,
    required this.quantity,
    required this.averagePrice,
  });
  final String symbol;
  final int quantity;
  final double averagePrice;

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'quantity': quantity,
    'averagePrice': averagePrice,
  };

  factory Holding.fromJson(Map<String, dynamic> json) => Holding(
    symbol: json['symbol'] as String,
    quantity: json['quantity'] as int,
    averagePrice: (json['averagePrice'] as num).toDouble(),
  );
}

enum OrderSide { buy, sell }

class Trade {
  const Trade({
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.price,
    required this.time,
  });
  final String symbol;
  final OrderSide side;
  final int quantity;
  final double price;
  final DateTime time;

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'side': side.name,
    'quantity': quantity,
    'price': price,
    'time': time.toIso8601String(),
  };

  factory Trade.fromJson(Map<String, dynamic> json) => Trade(
    symbol: json['symbol'] as String,
    side: OrderSide.values.firstWhere((e) => e.name == json['side']),
    quantity: json['quantity'] as int,
    price: (json['price'] as num).toDouble(),
    time: DateTime.parse(json['time'] as String),
  );
}

class FuturesPosition {
  const FuturesPosition({
    required this.id,
    required this.symbol,
    required this.side,
    required this.leverage,
    required this.entryPrice,
    required this.quantity,
    required this.margin,
  });

  final String id;
  final String symbol;
  final OrderSide side;
  final int leverage;
  final double entryPrice;
  final double quantity;
  final double margin;

  double get liquidationPrice {
    if (side == OrderSide.buy) {
      return entryPrice - (entryPrice / leverage);
    } else {
      return entryPrice + (entryPrice / leverage);
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'symbol': symbol,
    'side': side.name,
    'leverage': leverage,
    'entryPrice': entryPrice,
    'quantity': quantity,
    'margin': margin,
  };

  factory FuturesPosition.fromJson(Map<String, dynamic> json) => FuturesPosition(
    id: json['id'] as String,
    symbol: json['symbol'] as String,
    side: OrderSide.values.firstWhere((e) => e.name == json['side']),
    leverage: json['leverage'] as int,
    entryPrice: (json['entryPrice'] as num).toDouble(),
    quantity: (json['quantity'] as num).toDouble(),
    margin: (json['margin'] as num).toDouble(),
  );
}

class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.reward,
    required this.target,
    this.progress = 0,
    this.completed = false,
  });
  final String id;
  final String title;
  final int reward;
  final int target;
  final int progress;
  final bool completed;

  Mission copyWith({int? progress, bool? completed}) {
    return Mission(
      id: id,
      title: title,
      reward: reward,
      target: target,
      progress: progress ?? this.progress,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'reward': reward,
    'target': target,
    'progress': progress,
    'completed': completed,
  };

  factory Mission.fromJson(Map<String, dynamic> json) => Mission(
    id: json['id'] as String,
    title: json['title'] as String,
    reward: json['reward'] as int? ?? 100,
    target: json['target'] as int? ?? 1,
    progress: json['progress'] as int? ?? 0,
    completed: json['completed'] as bool? ?? false,
  );
}

class Badge {
  final String id;
  final String title;
  final String description;
  final String icon;

  const Badge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

const ALL_BADGES = [
  Badge(id: 'b1', title: 'First Blood', description: 'Make your first trade', icon: '🩸'),
  Badge(id: 'b2', title: 'Active Trader', description: 'Make 10 trades', icon: '⚡'),
  Badge(id: 'b3', title: 'Whale Status', description: 'Reach 2,00,00,000 balance', icon: '🐋'),
  Badge(id: 'b4', title: 'Diamond Hands', description: 'Hold any asset', icon: '💎'),
  Badge(id: 'b5', title: 'Diversified', description: 'Hold 3 different assets', icon: '🌐'),
];

class UserProfile {
  const UserProfile({
    required this.name,
    required this.experienceLevel,
    required this.virtualBalance,
    required this.xp,
    required this.streak,
    required this.watchlist,
    this.publicUid = '',
    this.unlockedBadges = const {},
    this.completedMissions = const {},
    this.preferredCurrency = 'INR',
    this.preferredLanguage = 'English',
    this.themeMode = 'Dark',
    this.lastDailyClaim,
    this.lastQuizAttempt,
    this.email = '',
    this.photoUrl = '',
  });
  final String name;
  final String experienceLevel;
  final double virtualBalance;
  final int xp;
  final int streak;
  final Set<String> watchlist;
  final String publicUid;
  final Set<String> unlockedBadges;
  final Set<String> completedMissions;
  final String preferredCurrency;
  final String preferredLanguage;
  final String themeMode;
  final String? lastDailyClaim;
  final String? lastQuizAttempt;
  final String email;
  final String photoUrl;

  UserProfile copyWith({
    String? name,
    String? experienceLevel,
    double? virtualBalance,
    int? xp,
    int? streak,
    Set<String>? watchlist,
    String? publicUid,
    Set<String>? unlockedBadges,
    Set<String>? completedMissions,
    String? preferredCurrency,
    String? preferredLanguage,
    String? themeMode,
    String? lastDailyClaim,
    String? lastQuizAttempt,
    String? email,
    String? photoUrl,
  }) {
    return UserProfile(
      name: name ?? this.name,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      virtualBalance: virtualBalance ?? this.virtualBalance,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      watchlist: watchlist ?? this.watchlist,
      publicUid: publicUid ?? this.publicUid,
      unlockedBadges: unlockedBadges ?? this.unlockedBadges,
      completedMissions: completedMissions ?? this.completedMissions,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      themeMode: themeMode ?? this.themeMode,
      lastDailyClaim: lastDailyClaim ?? this.lastDailyClaim,
      lastQuizAttempt: lastQuizAttempt ?? this.lastQuizAttempt,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'experienceLevel': experienceLevel,
    'virtualBalance': virtualBalance,
    'xp': xp,
    'streak': streak,
    'watchlist': watchlist.toList(),
    'publicUid': publicUid,
    'unlockedBadges': unlockedBadges.toList(),
    'completedMissions': completedMissions.toList(),
    'preferredCurrency': preferredCurrency,
    'preferredLanguage': preferredLanguage,
    'themeMode': themeMode,
    'lastDailyClaim': lastDailyClaim,
    'lastQuizAttempt': lastQuizAttempt,
    'email': email,
    'photoUrl': photoUrl,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? 'Guest',
    experienceLevel: json['experienceLevel'] as String? ?? 'Beginner',
    virtualBalance: (json['virtualBalance'] as num?)?.toDouble() ?? 0.0,
    xp: json['xp'] as int? ?? 0,
    streak: json['streak'] as int? ?? 1,
    watchlist: Set<String>.from(json['watchlist'] as List? ?? []),
    publicUid: json['publicUid'] as String? ?? '',
    unlockedBadges: Set<String>.from(json['unlockedBadges'] as List? ?? []),
    completedMissions: Set<String>.from(json['completedMissions'] as List? ?? []),
    preferredCurrency: json['preferredCurrency'] as String? ?? 'INR',
    preferredLanguage: json['preferredLanguage'] as String? ?? 'English',
    themeMode: json['themeMode'] as String? ?? 'Dark',
    lastDailyClaim: json['lastDailyClaim'] as String?,
    lastQuizAttempt: json['lastQuizAttempt'] as String?,
    email: json['email'] as String? ?? '',
    photoUrl: json['photoUrl'] as String? ?? '',
  );
}

class MoneyRequest {
  const MoneyRequest({
    required this.id,
    required this.requesterUid,
    required this.requesterId,
    required this.amount,
    required this.reason,
    required this.requesterNetWorth,
    required this.status, // 'pending', 'approved', 'rejected'
    this.adminMessage,
    this.createdAt,
    this.previousBalance,
    this.newBalance,
  });

  final String id;
  final String requesterUid;
  final String requesterId;
  final double amount;
  final String reason;
  final double requesterNetWorth;
  final String status;
  final String? adminMessage;
  final DateTime? createdAt;
  final double? previousBalance;
  final double? newBalance;

  Map<String, dynamic> toJson() => {
    'id': id,
    'requesterUid': requesterUid,
    'requesterId': requesterId,
    'amount': amount,
    'reason': reason,
    'requesterNetWorth': requesterNetWorth,
    'status': status,
    if (adminMessage != null) 'adminMessage': adminMessage,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (previousBalance != null) 'previousBalance': previousBalance,
    if (newBalance != null) 'newBalance': newBalance,
  };

  factory MoneyRequest.fromJson(Map<String, dynamic> json) => MoneyRequest(
    id: json['id'] as String? ?? '',
    requesterUid: json['requesterUid'] as String? ?? '',
    requesterId: json['requesterId'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    reason: json['reason'] as String? ?? '',
    requesterNetWorth: (json['requesterNetWorth'] as num?)?.toDouble() ?? 0.0,
    status: json['status'] as String? ?? 'pending',
    adminMessage: json['adminMessage'] as String?,
    createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
    previousBalance: (json['previousBalance'] as num?)?.toDouble(),
    newBalance: (json['newBalance'] as num?)?.toDouble(),
  );
}

