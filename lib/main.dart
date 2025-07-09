import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // YORUM SATIRI
// import 'package:permission_handler/permission_handler.dart'; // YORUM SATIRI
import 'motor_status_page.dart'; // Bu sayfa aktif kalacak

/*
// ----- BLE AYARLARI (GEÇİCİ OLARAK DEVRE DIŞI) -----
final Guid serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
final Guid uptimeCharacteristicUuid = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");
final Guid messageCharacteristicUuid = Guid("a1b2c3d4-e5f6-7890-1234-567890abcdef");
const String targetDeviceName = "ESP32_Uptime_Monitor";
*/

void main() {
  /*
  // Donanım izinleri ve BLE başlatma kodları geçici olarak devre dışı
  if (Platform.isAndroid) {
    WidgetsFlutterBinding.ensureInitialized();
    [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request().then((status) {
      runApp(const UptimeMonitorApp());
    });
  } else {
    runApp(const UptimeMonitorApp());
  }
  */
  // Sadece uygulamayı çalıştır
  runApp(const UptimeMonitorApp());
}

class UptimeMonitorApp extends StatelessWidget {
  const UptimeMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Proje adını daha genel bir hale getirebiliriz
      title: 'Motor Kontrol Arayüzü',
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
  /*
  // ----- BLE İLE İLGİLİ TÜM DEĞİŞKENLER YORUM SATIRINDA -----
  BluetoothDevice? _esp32Device;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<int>>? _uptimeNotificationSubscription;
  StreamSubscription<List<int>>? _messageNotificationSubscription;

  String _statusMessage = "Başlatılıyor...";
  String _uptimeMessage = "Bağlantı bekleniyor...";
  String _lastMessage = "Henüz mesaj alınmadı.";
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isScanning = false;
  */

  @override
  void initState() {
    super.initState();
    // _startScan(); // BLE taraması devre dışı
  }

  /*
  // ----- TÜM BLE FONKSİYONLARI YORUM SATIRINDA -----

  Future<void> _cleanupSubscriptions() async {
    // ...
  }

  void _startScan() {
    // ...
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    // ...
  }

  void _onDeviceConnected() async {
    // ...
  }

  Future<void> _discoverServices() async {
    // ...
  }

  Future<void> _subscribeToCharacteristics(List<BluetoothCharacteristic> characteristics) async {
    // ...
  }
  
  Future<void> _subscribeToNotification(
    BluetoothCharacteristic characteristic,
    void Function(List<int> value) onData,
  ) async {
    // ...
  }

  void _handleUptimeData(List<int> value) {
    // ...
  }

  void _handleMessageData(List<int> value) {
    // ...
  }

  String _formatDuration(int totalSeconds) {
    // ...
  }

  void _stopAllActivities(String message, {bool performDisconnect = true}) {
    // ...
  }
  */

  @override
  void dispose() {
    // _stopAllActivities("Uygulama kapatıldı."); // BLE temizliği devre dışı
    super.dispose();
  }

  // --- YENİ, TASARIM ODAKLI BUILD METODU ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.engineering_outlined,
                size: 100,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                'Motor Kontrol Sistemi',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Motor durumlarını görüntülemek için devam edin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MotorStatusPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Motorları Görüntüle'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /*
  // ----- ESKİ BUILD METODU VE YARDIMCI WIDGET'I YORUM SATIRINDA -----
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ESP32 Canlı Monitor"),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              Column(
                children: [
                  if (_isScanning || _isConnecting)
                    const CircularProgressIndicator()
                  else
                    Icon(
                      _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      size: 40,
                      color: _isConnected ? Colors.greenAccent : Colors.grey.shade600,
                    ),
                  const SizedBox(height: 10),
                  Text(
                    _statusMessage,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              _buildInfoCard(
                icon: Icons.timer_outlined,
                color: Colors.blueAccent,
                title: 'Çalışma Süresi',
                value: _uptimeMessage,
              ),
              _buildInfoCard(
                icon: Icons.chat_bubble_outline_rounded,
                color: Colors.purpleAccent,
                title: 'Gelen Son Mesaj',
                value: _lastMessage,
                isItalic: true,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_isConnected || _isScanning || _isConnecting) ? null : _startScan,
        backgroundColor: (_isConnected || _isScanning || _isConnecting) ? Colors.grey.shade800 : Theme.of(context).colorScheme.secondary,
        label: const Text("Tekrar Tara"),
        icon: const Icon(Icons.search),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    bool isItalic = false,
  }) {
    return Container(
      // ...
    );
  }
  */
}
