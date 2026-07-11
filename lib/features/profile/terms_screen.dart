import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last Updated: Today',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Nature of the Application',
              'This application ("the App") is strictly a paper-trading simulator and educational tool. It is designed to simulate cryptocurrency market mechanics, including spot trading, futures trading, and portfolio management. The App is NOT an exchange, brokerage, or financial institution.',
            ),
            _buildSection(
              '2. Virtual Currency & No Real Money',
              'All funds, balances, and assets displayed within the App are entirely virtual and simulated. You cannot deposit, withdraw, or transfer real money or real cryptocurrencies into or out of the App. The virtual currency has no real-world value and cannot be exchanged for fiat currency or other assets.',
            ),
            _buildSection(
              '3. Not Financial Advice',
              'The information, tools, and simulated market data provided by the App do not constitute financial, investment, legal, or tax advice. Any trading strategies you test or execute within the App are for educational and entertainment purposes only. Past simulated performance is not indicative of future real-world results.',
            ),
            _buildSection(
              '4. Market Data Accuracy',
              'The App pulls market pricing, news, and other data from third-party public sources (such as Binance and CoinTelegraph). While we strive for accuracy, we make no guarantees regarding the timeliness, precision, or reliability of this data. Delays, inaccuracies, or downtime in third-party feeds may occur.',
            ),
            _buildSection(
              '5. Simulated Features & Mechanics',
              'Features such as "Request Money", "Buy", "Sell", "Long", "Short", and "Liquidations" operate strictly within the bounds of the simulation software. Requesting money from the "Admin" merely credits your virtual account with simulated funds and does not involve real banking or financial networks.',
            ),
            _buildSection(
              '6. Limitation of Liability',
              'Under no circumstances shall the creators, developers, or operators of the App be held liable for any real-world financial losses or damages resulting from the use of this simulator, your reliance on simulated market data, or the application of strategies tested within the App to actual real-world trading platforms.',
            ),
            _buildSection(
              '7. User Conduct',
              'You agree to use the App solely for its intended educational purposes. You must not attempt to manipulate the simulation, exploit bugs to artificially inflate virtual balances, or reverse engineer the App\'s data feeds or infrastructure.',
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'By using this App, you accept these terms in full.',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
