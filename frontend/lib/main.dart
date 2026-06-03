import 'package:flutter/material.dart';
import 'screens/search_screen.dart';
import 'screens/results_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const RealTokenApp());
}

class RealTokenApp extends StatelessWidget {
  const RealTokenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RealToken | Tokenized Real Estate Search',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const SearchScreen(),
            );
          case '/results':
            final args = settings.arguments;
            if (args is ResultsScreenArgs) {
              return MaterialPageRoute(
                builder: (_) => ResultsScreen(args: args),
              );
            }
            // Fallback: navigate back to search if args are missing
            return MaterialPageRoute(
              builder: (_) => const SearchScreen(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const SearchScreen(),
            );
        }
      },
    );
  }
}
