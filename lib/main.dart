// lib/main.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_page.dart';
import 'package:uptime_monitor_final/settings_service.dart'; // YENİ IMPORT

void main() async {
  // Bu async/await yapısı izin istemek için daha güvenilirdir.
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().init(); // YENİ EKLENEN KOD: Ayar servisini başlat
  if (Platform.isAndroid) {
    await requestPermissions();
  }
  // Provider olmadan, direkt uygulamayı çalıştır
  runApp(const MotorMonitorApp());
}

Future<void> requestPermissions() async {
  // Tüm gerekli izinleri iste
  Map<Permission, PermissionStatus> statuses = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
    Permission.location, // Konum izni kritik
  ].request();

  // İzin durumlarını kontrol et (opsiyonel ama iyi bir pratik)
  statuses.forEach((permission, status) {
    print('${permission.toString()}: ${status.toString()}');
    if (status.isDenied) {
      print('İzin reddedildi: $permission');
    }
  });
}

class MotorMonitorApp extends StatelessWidget {
  const MotorMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Motor Monitörü',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        colorScheme: ColorScheme.fromSwatch(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
        ).copyWith(secondary: Colors.blueAccent),
      ),
      home: const HomePage(), // HomePage'i direkt çağır
    );
  }
}
