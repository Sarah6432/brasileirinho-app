import 'package:brasileirinho/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:brasileirinho/features/view/login_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brasileirinho',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginView(),
    );
  }
}