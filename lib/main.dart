import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/add_listing_screen.dart';
import 'screens/browsing_screen.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwapWear',
      theme: AppTheme.lightTheme,
      home: BrowsingScreen(userId: 'demouser123'),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text("Firebase Connected ✅")));
  }
}
