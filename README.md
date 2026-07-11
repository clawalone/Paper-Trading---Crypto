<div align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=white" alt="Firebase" />
  <img src="https://img.shields.io/badge/Riverpod-000000?style=for-the-badge&logo=dart&logoColor=white" alt="Riverpod" />
  <img src="https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge" alt="License" />
</div>

<h1 align="center">AcadrioTrade (Stock Arena) 📈</h1>

<p align="center">
  <b>A highly gamified, real-time paper-trading crypto simulator built with Flutter and Firebase.</b><br>
  Experience the thrill of trading cryptocurrencies in a risk-free environment. Compete on leaderboards, learn trading strategies through interactive quizzes, and build your virtual portfolio.
</p>

---

## ✨ Features

- **Live Crypto Data**: Real-time ticker prices and candlestick charts via Binance WebSockets.
- **Advanced Charting**: Fully interactive 1D/1W/1M/1Y/5Y candlestick and line charts with volume indicators.
- **Futures & Margin Trading**: Practice advanced trading strategies with leverage, liquidation prices, and isolated/cross margins.
- **Gamified Learning**: Earn XP, level up, complete daily missions, and unlock badges to become a pro trader.
- **Global Leaderboard**: Compete against friends and traders worldwide for the top portfolio rank.
- **Multi-Currency Support**: Dynamically switch your portfolio view between USD and INR base currencies.
- **Cross-Platform**: A responsive web terminal and a polished native mobile experience.

---

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Cross-platform Mobile & Web)
- **State Management**: [Riverpod](https://riverpod.dev/)
- **Backend**: [Firebase](https://firebase.google.com/) (Auth, Firestore, Hosting)
- **Market Data**: Binance REST API & WebSocket Streams
- **Charts**: Syncfusion Flutter Charts & FL Chart

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (`>=3.4.0`)
- Firebase CLI (for backend setup)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/clawalone/Paper-Trading---Crypto.git
   cd Paper-Trading---Crypto
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**
   Connect your own Firebase project by configuring `google-services.json` (Android), `GoogleService-Info.plist` (iOS), or `firebase_options.dart`.

4. **Run the App**
   ```bash
   flutter run
   ```

---

## 🤝 Contributing
Contributions, issues, and feature requests are welcome! Feel free to check out the [issues page](../../issues).

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

<div align="center">
  <i>Built with ❤️ using Flutter</i>
</div>
