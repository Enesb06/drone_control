import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'motor_status_page.dart';

// import 'dart:typed_data'; // Artık uptime için kullanılmadığı için kaldırabiliriz
// ----- YENİ BLE MİMARİSİNE GÖRE UUID'LER -----
// Not: ESP32 kodundaki UUID'lerle aynı olmalı
final Guid serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
// Uptime Characteristic UUID'si ESP32 kodunda tanımlı olmadığı için kaldırıldı.
// Eğer ESP32'den çalışma süresi verisi de almak isterseniz, ESP32 koduna eklemeniz gerekir.
// final Guid uptimeCharacteristicUuid = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");

// Flutter uygulamasının arayacağı cihaz adı, ESP32 kodundaki DEVICE_NAME ile AYNI OLMALI
const String targetDeviceName = "ESP32_Graph_Tester"; // <-- BURAYI DEĞİŞTİRDİK

void main() {
  if (Platform.isAndroid) {
    WidgetsFlutterBinding.ensureInitialized();
    [
      //Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission
          .location, // Android 12 öncesi Bluetooth için konum izni gerekliydi.
    ].request().then((status) {
      runApp(const MotorMonitorApp());
    });
  } else {
    runApp(const MotorMonitorApp());
  }
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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BluetoothDevice? _esp32Device;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  // Uptime karakteristiği kaldırıldığı için bu abonelik de kaldırıldı.
  // StreamSubscription<List<int>>? _uptimeNotificationSubscription;

  String _statusMessage = "Başlatılıyor...";
  // Uptime mesajı kaldırıldı.
  // String _uptimeMessage = "Bağlantı bekleniyor...";
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  // Sadece ilgili abonelikleri temizle
  Future<void> _cleanupSubscriptions() async {
    // _uptimeNotificationSubscription?.cancel(); // Kaldırıldı
    await _connectionStateSubscription?.cancel();
    await _scanSubscription?.cancel();
  }

  void _startScan() {
    if (_isScanning || _isConnected || _isConnecting) return;
    setState(() {
      _isScanning = true;
      _statusMessage = "Cihaz aranıyor...";
    });

    FlutterBluePlus.startScan(
      withServices: [
        serviceUuid,
      ], // Sadece belirtilen servis UUID'sini içeren cihazları tara
      timeout: const Duration(seconds: 15),
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          // Cihaz adını kontrol ederek doğru cihazı bul
          var foundDevice = results.firstWhere(
            (result) => result.device.platformName == targetDeviceName,
            orElse: () => throw Exception(
              'Cihaz bulunamadı: $targetDeviceName',
            ), // Cihaz bulunamazsa hata fırlat
          );

          FlutterBluePlus.stopScan();
          _connectToDevice(foundDevice.device);
        }
      },
      onError: (e) {
        // Hata durumunda (örn. orElse hatası)
        if (mounted) {
          FlutterBluePlus.stopScan();
          setState(() {
            _isScanning = false;
            _statusMessage = "Tarama Hatası: ${e.toString()}";
          });
        }
      },
    );

    Timer(const Duration(seconds: 15), () {
      if (mounted && _isScanning) {
        FlutterBluePlus.stopScan();
        setState(() {
          _isScanning = false;
          _statusMessage = "$targetDeviceName bulunamadı.";
        });
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _scanSubscription?.cancel();
    _isScanning = false;
    if (_isConnected || _isConnecting) return;

    setState(() {
      _isConnecting = true;
      _esp32Device = device;
      _statusMessage = "Bağlanılıyor...";
    });

    _connectionStateSubscription = device.connectionState.listen((state) {
      if (mounted) {
        if (state == BluetoothConnectionState.connected) {
          _onDeviceConnected();
        } else if (state == BluetoothConnectionState.disconnected) {
          _stopAllActivities("Bağlantı koptu.", performDisconnect: false);
        }
      }
    });

    try {
      await device.connect(timeout: const Duration(seconds: 15));
    } catch (e) {
      if (mounted) _stopAllActivities("Bağlantı başarısız: $e");
    }
  }

  void _onDeviceConnected() async {
    if (!mounted) return;
    setState(() {
      _isConnected = true;
      _isConnecting = false;
      _statusMessage = "Bağlandı!";
    });
    // Servisleri keşfet, ancak artık uptime karakteristiklerini aramıyoruz
    await _discoverServices();
  }

  Future<void> _discoverServices() async {
    if (_esp32Device == null) return;
    await _esp32Device!.discoverServices();
    // Normalde burada servis ve karakteristikler kontrol edilirdi.
    // Ancak bu sayfada sadece bağlantı kurulduğu için,
    // motor_status_page'de ilgili servis ve karakteristikler aranacak.
  }

  // Uptime veri işleme fonksiyonu kaldırıldı.
  // void _handleUptimeData(List<int> value) { ... }
  // Süre formatlama fonksiyonu kaldırıldı.
  // String _formatDuration(int totalSeconds) { ... }

  void _stopAllActivities(String message, {bool performDisconnect = true}) {
    if (performDisconnect) _esp32Device?.disconnect();
    _cleanupSubscriptions();
    if (mounted) {
      setState(() {
        _isScanning = false;
        _isConnecting = false;
        _isConnected = false;
        _statusMessage = message;
        // _uptimeMessage = "Bağlantı bekleniyor..."; // Kaldırıldı
      });
    }
  }

  @override
  void dispose() {
    _stopAllActivities("Uygulama kapatıldı.");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(targetDeviceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart_rounded),
            tooltip: 'Canlı Veri Grafiği', // Tooltip güncellendi
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
                : null, // Bağlı değilse buton pasif
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
            const SizedBox(height: 10),
            // Uptime mesajı kaldırıldı.
            /*
            if (_isConnected)
              Text(
                "Çalışma Süresi: $_uptimeMessage",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            */
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_isConnected || _isConnecting || _isScanning)
            ? null // Zaten bağlı/bağlanıyor/tarıyorsa pasif
            : _startScan, // Değilse taramayı başlat
        label: const Text("Tekrar Tara"),
        icon: const Icon(Icons.search),
      ),
    );
  }
}
