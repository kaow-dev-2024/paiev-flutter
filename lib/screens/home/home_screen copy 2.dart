import 'package:flutter/material.dart';

class ChargeApp extends StatelessWidget {
  const ChargeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PAI EV Charger')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ev_station, size: 72),
            const SizedBox(height: 16),
            const Text(
              'Welcome to PAI EV',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'คุณเข้าสู่ระบบเรียบร้อยแล้ว',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // ตัวอย่าง logout ง่าย ๆ
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Background color
                foregroundColor: Colors.white, // Text/icon color
                elevation: 8.0, // Shadow elevation
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ), // Internal padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0), // Rounded corners
                ),
                textStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ), // Text style
              ),
              child: const Text('ออกจากระบบ'),
            ),
          ],
        ),
      ),
    );
  }
}
