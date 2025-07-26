import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:uptime_monitor_final/saved_graphs_page.dart';
import 'motor_status_page.dart';
import 'package:uptime_monitor_final/settings_page.dart';

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
  StreamSubscription<bool>? _isScanningSubscription;

  String _statusMessage = "Başlatılıyor...";
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;
      if (state == BluetoothAdapterState.on) {
        setState(() => _statusMessage = "Bluetooth açık. Taramaya hazır.");
      } else {
        _stopAllActivities("Bluetooth kapalı.");
      }
    });
  }

  Future<void> _cleanupSubscriptions() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    await _isScanningSubscription?.cancel();
    _isScanningSubscription = null;
  }

  void _startScan() {
    if (_isScanning || _isConnecting || _isConnected) return;

    _cleanupSubscriptions();

    try {
      _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
        if (mounted) {
          setState(() => _isScanning = scanning);
          if (!_isScanning && !_isConnected && !_isConnecting) {
            setState(() {
              _statusMessage = "$targetDeviceName bulunamadı.";
            });
          }
        }
      });

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          if (result.device.platformName == targetDeviceName) {
            print(">>> Cihaz bulundu: ${result.device.platformName} <<<");
            FlutterBluePlus.stopScan();
            _connectToDevice(result.device);
            _scanSubscription?.cancel();
            return;
          }
        }
      });

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

  // ============== MANTIĞIN GÜÇLENDİRİLDİĞİ YER ==============
  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_isConnecting || _isConnected) return;

    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();

    if (mounted) {
      setState(() {
        _isConnecting = true;
        _statusMessage = "Bağlanılıyor...";
      });
    }

    // Bağlantı durumu dinleyicisini, bağlanma işleminden ÖNCE ayarlıyoruz.
    // Bu, hiçbir durumu kaçırmamamızı sağlar.
    _connectionStateSubscription = device.connectionState.listen((state) {
      if (!mounted) return;

      // Gelen her duruma göre state'i güncelliyoruz.
      switch (state) {
        case BluetoothConnectionState.connected:
          // === YARIŞ DURUMUNU ÖNLEYEN ÇEKİRDEK ÇÖZÜM ===
          // Cihaz bağlandığında, ilgili TÜM değişkenleri
          // tek bir setState çağrısı içinde "atomik" olarak güncelliyoruz.
          // Bu, _isConnected true iken _esp32Device'ın null olmasını imkansız hale getirir.
          setState(() {
            _isConnected = true;
            _isConnecting = false;
            _esp32Device = device; // EN ÖNEMLİ EKLEME!
            _statusMessage = "Bağlandı!";
          });
          break;
        case BluetoothConnectionState.disconnected:
          // Bağlantı koptuğunda her şeyi sıfırlayan merkezi fonksiyonu çağırıyoruz.
          _stopAllActivities("Bağlantı koptu.");
          break;
        default:
          // Diğer durumlar (connecting, disconnecting) için şimdilik bir şey yapmıyoruz.
          break;
      }
    });

    try {
      // timeoute'u biraz daha uzun tutarak zayıf sinyallere şans veriyoruz.
      await device.connect(timeout: const Duration(seconds: 20));
    } catch (e) {
      // Eğer connect metodu hata fırlatırsa (örn: timeout) ve biz hala
      // 'connected' durumuna geçmediysek, işlemi durdur.
      if (mounted && !_isConnected) {
        _stopAllActivities("Bağlantı başarısız: $e");
      }
    }
  }

  // _onDeviceConnected fonksiyonuna artık ihtiyacımız kalmadı, mantığı yukarı taşıdık.

  void _stopAllActivities(String message, {bool performDisconnect = true}) {
    if (performDisconnect) {
      // _esp32Device null olsa bile sorun çıkarmayacak güvenli disconnect çağrısı.
      _esp32Device?.disconnect().catchError((e) {
        print("Disconnect hatası (normal olabilir): $e");
      });
    }
    _cleanupSubscriptions();
    if (mounted) {
      setState(() {
        _isScanning = false;
        _isConnecting = false;
        _isConnected = false;
        _esp32Device = null; // HER ŞEYİ SIFIRLA
        _statusMessage = message;
      });
    }
  }
  // ==============================================================

  @override
  void dispose() {
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
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            tooltip: 'Ayarlar',
          ),
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
            // Koşulumuz hala aynı ve şimdi çok daha güvenilir çalışacak.
            onPressed: (_isConnected && _esp32Device != null)
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
