# StockArena

StockArena is a Flutter paper-trading app concept inspired by modern investing apps, with a gamified learning loop.

Users receive virtual cash, search stocks, inspect delayed-style charts, buy and sell with simulated money, track portfolio profit/loss, complete missions, earn badges and XP, build watchlists, and compete on a leaderboard.

## Current MVP

- Onboarding with experience selection
- Login/signup style entry
- Home dashboard with virtual balance, portfolio value, profit/loss, gainers/losers, and missions
- Market screen with search, filters, trending stocks, gainers, and losers
- Stock detail page with line/candlestick chart toggle, 1D/1W/1M/1Y/5Y ranges, volume bars, indicators, and moving average display
- Buy/sell flow with quantity, market price, estimated cost, and confirmation
- Portfolio holdings and transaction history
- Watchlist
- Missions, rewards, badges, streaks, levels, learning quiz, and leaderboard

## Run

```powershell
flutter pub get
flutter run
```

If this directory does not yet contain platform folders such as `android`, `ios`, or `web`, run:

```powershell
flutter create .
```

Then keep the generated platform files and this `lib/main.dart`.
