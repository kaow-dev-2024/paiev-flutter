import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
// import 'screens/auth/otp_verify_screen.dart';
import 'screens/home/home_screen.dart';

void main() {
  runApp(const PAIevApp());
}

class PAIevApp extends StatelessWidget {
  const PAIevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PAI EV Charger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const ChargeApp(),
        // OTP ใช้ push แบบส่ง args อยู่แล้ว เลยไม่ต้องใส่ใน routes map ก็ได้
      },
    );
  }
}
