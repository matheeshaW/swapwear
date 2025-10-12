import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'services/profile_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/achievements_service.dart';
import 'firebase_messaging_handler.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/browsing_screen.dart';
import 'screens/dev_swap_test_screen.dart';
import 'screens/add_provider_page.dart';
import 'screens/provider_dashboard.dart';
import 'screens/track_delivery_page.dart';
import 'screens/enhanced_track_delivery_page.dart';
import 'screens/notifications_screen.dart';
import 'screens/eco_impact_dashboard.dart';
import 'screens/achievements_page.dart';
import 'screens/chat_screen.dart';
import 'screens/my_swaps_screen.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize Firebase messaging background handler
  FirebaseMessagingHandler().initialize();

  // Initialize notification service
  await NotificationService().initialize();

  // Initialize achievements service
  await AchievementsService().initializeUserStats(
    FirebaseAuth.instance.currentUser?.uid ?? '',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwapWear',
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/admin': (context) => const AdminDashboard(),
        '/add-provider': (context) => const AddProviderPage(),
        '/provider-dashboard': (context) => const ProviderDashboard(),
        '/notifications': (context) => const NotificationsScreen(),
        '/eco-impact': (context) => const EcoImpactDashboard(),
        '/achievements': (context) => const AchievementsPage(),
        '/track-delivery': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return TrackDeliveryPage(swapId: args?['swapId'] ?? '');
        },
        '/enhanced-track-delivery': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return EnhancedTrackDeliveryPage(swapId: args?['swapId'] ?? '');
        },
        '/chat': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return ChatScreen(
            chatId: args?['chatId'] ?? '',
            currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
            swapId: args?['swapId'],
          );
        },
        '/my-swaps': (context) => const MySwapsScreen(),
        '/dev-swap-test': (context) => const DevSwapTestScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/browse') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => BrowsingScreen(
              userId: args?['userId'] ?? '',
              initialTab: args?['initialTab'],
            ),
          );
        }
        return null; // fallback to default
      },
      home: const AuthGate(),
      theme: AppTheme.lightTheme,
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // Ensure Firestore profile exists for authenticated users
        ProfileService().ensureUserProfile(user: user);

        // Initialize achievements for authenticated users
        AchievementsService().initializeUserStats(user.uid);

        // Check user role and route accordingly
        return FutureBuilder<String?>(
          future: _authService.getUserRole(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = roleSnapshot.data;

            if (role == 'provider') {
              return const ProviderDashboard();
            } else {
              return BrowsingScreen(userId: user.uid);
            }
          },
        );
      },
    );
  }
}
