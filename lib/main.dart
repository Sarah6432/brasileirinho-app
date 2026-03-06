import 'package:brasileirinho/features/service/auth_manager.dart';
import 'package:brasileirinho/features/view/feedpage_view.dart';
import 'package:brasileirinho/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:brasileirinho/features/view/login_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthManager.instance.loadAccounts();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Se já existe uma sessão salva, vai direto pro Feed
    final hasSession = AuthManager.instance.currentSession != null;

    return MaterialApp(
      title: 'Brasileirinho',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: hasSession ? const FeedPage() : const LoginView(),
    );
  }
}
