import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:uptime_monitor_final/saved_graphs_page.dart'; // Proje adınıza göre yolu kontrol edin
import 'motor_status_page.dart';

// Bu sabitler projenizin her yerinde aynı kalmalı
final Guid serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
const String targetDeviceName = "ESP32_Graph_Tester";

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BluetoothDevice? _esp32Device;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<bool>?
  _isScanningSubscription; // Tarama durumunu dinlemek için

  String _statusMessage = "Başlatılıyor...";
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    // Bluetooth adaptör durumunu dinle
    FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;
      if (state == BluetoothAdapterState.on) {
        setState(() => _statusMessage = "Bluetooth açık. Taramaya hazır.");
      } else {
        _stopAllActivities("Bluetooth kapalı.");
      }
    });
  }

  // Tüm abonelikleri güvenli bir şekilde iptal et
  Future<void> _cleanupSubscriptions() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    await _isScanningSubscription?.cancel();
    _isScanningSubscription = null;
  }

  // --- ZAMANLAMA HATASINI GİDEREN YENİ TARAMA METODU ---
  void _startScan() {
    if (_isScanning || _isConnecting || _isConnected) return;

    _cleanupSubscriptions(); // Her zaman temiz bir başlangıç yap

    try {
      // 1. Tarama durumunu dinlemeye başla. Bu, "bulunamadı" mesajını doğru zamanda göstermemizi sağlar.
      _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
        if (mounted) {
          setState(() {
            _isScanning = scanning;
          });
          // Eğer tarama durduysa VE hala bağlanmadıysak/bağlanmıyorsak, o zaman cihaz bulunamamıştır.
          if (!_isScanning && !_isConnected && !_isConnecting) {
            setState(() {
              _statusMessage = "$targetDeviceName bulunamadı.";
            });
          }
        }
      });

      // 2. Tarama sonuçlarını dinle.
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        // Gelen her yeni sonuç listesinde cihazımızı ara
        for (var result in results) {
          if (result.device.platformName == targetDeviceName) {
            print(">>> Cihaz bulundu: ${result.device.platformName} <<<");

            // Cihazı bulur bulmaz taramayı durdur ve bağlan.
            // Bu, birden fazla kez bağlanma denemesini engeller.
            FlutterBluePlus.stopScan();
            _connectToDevice(result.device);

            // Artık tarama sonuçlarını dinlemeye gerek yok.
            _scanSubscription?.cancel();
            return; // Fonksiyondan çık
          }
        }
      });

      // 3. Taramayı başlat. Kendi Timer'ımız YOK. Kütüphanenin timeout'una güveniyoruz.
      setState(() {
        _statusMessage = "Cihaz aranıyor...";
      });
      FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      print("Tarama başlatma hatası: $e");
      _stopAllActivities("Tarama hatası: $e");
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    // Zaten bağlanıyorsak veya bağlıysak tekrar deneme
    if (_isConnecting || _isConnected) return;

    // Tarama ile ilgili abonelikleri temizle
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();

    if (mounted) {
      setState(() {
        _isConnecting = true;
        _isConnected = false;
        _isScanning = false;
        _esp32Device = device;
        _statusMessage = "Bağlanılıyor...";
      });
    }

    _connectionStateSubscription = device.connectionState.listen((state) {
      if (!mounted) return;
      if (state == BluetoothConnectionState.connected) {
        _onDeviceConnected();
      } else if (state == BluetoothConnectionState.disconnected) {
        _stopAllActivities("Bağlantı koptu.", performDisconnect: false);
      }
    });

    try {
      await device.connect(timeout: const Duration(seconds: 15));
    } catch (e) {
      // Bazen Android'de bağlantı başarılı olsa da bir istisna fırlatılabilir (GATT 133 hatası gibi).
      // Eğer cihaz zaten 'connected' durumuna geçtiyse, hatayı görmezden gelebiliriz.
      // 1 saniye sonra durumu kontrol et.
      await Future.delayed(const Duration(milliseconds: 1000));
      if (_isConnected) {
        print("Bağlantı hatası alındı ama cihaz zaten bağlı: $e");
        return;
      }
      if (mounted) _stopAllActivities("Bağlantı başarısız: $e");
    }
  }

  void _onDeviceConnected() {
    if (!mounted || _isConnected)
      return; // Zaten bağlı olarak ayarlandıysa tekrar girme

    setState(() {
      _isConnected = true;
      _isConnecting = false;
      _statusMessage = "Bağlandı!";
    });
  }

  void _stopAllActivities(String message, {bool performDisconnect = true}) {
    if (performDisconnect) {
      _esp32Device?.disconnect();
    }
    _cleanupSubscriptions();
    if (mounted) {
      setState(() {
        _isScanning = false;
        _isConnecting = false;
        _isConnected = false;
        _esp32Device = null;
        _statusMessage = message;
      });
    }
  }

  @override
  void dispose() {
    // Sadece abonelikleri temizle, cihaz bağlantısını kesme.
    // Bu, sayfa geçişlerinde bağlantının kopmasını engeller.
    _cleanupSubscriptions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(targetDeviceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedGraphsPage(),
                ),
              );
            },
            tooltip: 'Kaydedilen Grafikler',
          ),
          IconButton(
            icon: const Icon(Icons.show_chart_rounded),
            tooltip: 'Canlı Veri Grafiği',
            onPressed: _isConnected
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MotorStatusPage(device: _esp32Device!),
                      ),
                    );
                  }
                : null,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isScanning || _isConnecting)
              const CircularProgressIndicator()
            else
              Icon(
                _isConnected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                size: 80,
                color: _isConnected ? Colors.greenAccent : Colors.grey,
              ),
            const SizedBox(height: 20),
            Text(_statusMessage, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_isScanning || _isConnecting || _isConnected)
            ? null
            : _startScan,
        label: const Text("Tekrar Tara"),
        icon: const Icon(Icons.search),
      ),
    );
  }
}
