import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/app_theme.dart';
import 'features/home/home_shell.dart';
import 'firebase_options.dart';
import 'core/currency_formatters.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Fetch live currency exchange rate
  await CurrencyFormatters.initExchangeRate();
  
  runApp(
    const ProviderScope(
      child: TradeQuestApp(),
    ),
  );
}

class TradeQuestApp extends StatelessWidget {
  const TradeQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaperTrading - Crypto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeShell(),
    );
  }
}
