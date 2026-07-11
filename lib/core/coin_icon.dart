import 'package:flutter/material.dart';

class CoinIcon extends StatelessWidget {
  final String symbol;
  final double size;

  const CoinIcon({required this.symbol, this.size = 32, super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.network(
        'https://cdn.jsdelivr.net/gh/atomiclabs/cryptocurrency-icons@1a63530be6e374711a8554f31b17e4cb92c25fa5/128/color/${symbol.toLowerCase()}.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Color(0xFF1E2329),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              symbol.length >= 2 ? symbol.substring(0, 2).toUpperCase() : symbol.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.35,
              ),
            ),
          );
        },
      ),
    );
  }
}
