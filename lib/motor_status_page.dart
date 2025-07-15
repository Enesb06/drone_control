import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math'; // max fonksiyonu için

// ----- KULLANACAĞIMIZ UUID'LER (ESP32 İLE AYNI OLMALI) -----
final Guid serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
final Guid timeSeriesCharacteristicUuid1 = Guid(
  "c1d2e3f4-a5b6-c7d8-e9f0-a1b2c3d4e5f6", // Grafik 1 için
);
final Guid timeSeriesCharacteristicUuid2 = Guid(
  "e6a7b8c9-d0e1-f2a3-b4c5-d6e7f8a9b0c1", // Grafik 2 için YENİ
);

class MotorStatusPage extends StatefulWidget {
  final BluetoothDevice device;
  const MotorStatusPage({super.key, required this.device});

  @override
  State<MotorStatusPage> createState() => _MotorStatusPageState();
}

class _MotorStatusPageState extends State<MotorStatusPage> {
  // Grafik veri listeleri
  List<FlSpot> _liveDataSpots1 = []; // Sayfa 1 (Grafik 1) için
  List<FlSpot> _liveDataSpots2 = []; // Sayfa 2 (Grafik 2) için

  // BLE veri abonelikleri
  StreamSubscription<List<int>>? _dataSubscription1; // Grafik 1 için
  StreamSubscription<List<int>>? _dataSubscription2; // Grafik 2 için
  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  // Global bir zaman sayacı (saniye cinsinden). Veri geldikçe artacak.
  // Her iki grafiğin de X eksenini senkronize etmek için kullanılır.
  double _globalTime = 0;

  // ESP32'den gelen her veri noktasının süresi (ms)
  final int _dataPointIntervalMs =
      10; // <-- KRİTİK: ESP32'deki dataSendInterval ile AYNI OLMALI!

  // Ekranda aynı anda kaç saniyelik veri gösterileceğini belirler (5 saniyelik pencere)
  final int _displaySeconds = 5;
  // Ekranda gösterilecek maksimum nokta sayısı (5 saniye * (1000ms / 10ms_per_point) = 5 * 100 = 500 nokta)
  final int _maxDataPoints =
      500; // <-- KRİTİK: 5 saniyelik pencerede tutulacak nokta sayısı

  Timer? _graphStopTimer;
  final int _graphDurationSeconds = 30; // Grafik 30 saniye sonra duracak

  bool _isGraphRunning = true;

  int _currentPageIndex = 0; // 0: Sayfa1 (Grafik), 1: Sayfa2 (Grafik)

  @override
  void initState() {
    super.initState();
    _setupPage();
    _startGraphStopTimer();
  }

  @override
  void dispose() {
    _dataSubscription1?.cancel(); // Abonelikleri iptal etmeyi unutma
    _dataSubscription2?.cancel();
    _connectionSub?.cancel();
    _graphStopTimer?.cancel();
    super.dispose();
  }

  void _startGraphStopTimer() {
    _graphStopTimer = Timer(Duration(seconds: _graphDurationSeconds), () {
      if (mounted) {
        setState(() {
          _isGraphRunning = false; // Grafiği durdu olarak işaretle
        });
        _dataSubscription1?.cancel(); // Veri alma aboneliklerini iptal et
        _dataSubscription2?.cancel();
        print(
          "Grafikler 30 saniye dolduğu için durduruldu. Son ${_displaySeconds} saniye gösteriliyor.",
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Grafikler 30sn doldu. Son ${_displaySeconds}sn gösteriliyor.',
            ),
          ),
        );
      }
    });
  }

  Future<void> _setupPage() async {
    _connectionSub = widget.device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cihaz bağlantısı koptu.')),
          );
          Navigator.of(context).pop();
        }
      }
    });

    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      for (var s in services) {
        if (s.uuid == serviceUuid) {
          for (var c in s.characteristics) {
            // Grafik 1 karakteristik aboneliği
            if (c.uuid == timeSeriesCharacteristicUuid1) {
              await c.setNotifyValue(true);
              if (_isGraphRunning) {
                _dataSubscription1 = c.onValueReceived.listen(_handleLiveData1);
              }
            }
            // Grafik 2 karakteristik aboneliği
            else if (c.uuid == timeSeriesCharacteristicUuid2) {
              await c.setNotifyValue(true);
              if (_isGraphRunning) {
                _dataSubscription2 = c.onValueReceived.listen(_handleLiveData2);
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Servisler bulunamadı: $e')));
        Navigator.of(context).pop();
      }
    }
  }

  // Grafik 1 için veri işleme fonksiyonu
  void _handleLiveData1(List<int> value) {
    if (_isGraphRunning && value.length == 4) {
      final byteData = ByteData.sublistView(Uint8List.fromList(value));
      final double newYValue = byteData.getFloat32(0, Endian.little);

      setState(() {
        // Global zamanı sadece bir yerden güncelle (genel senkronizasyon için)
        // Eğer her iki karakteristik aynı anda bildirim gönderiyorsa
        // ve bu fonksiyon ilk çağrılan ise, burada güncelleyebiliriz.
        _globalTime += (_dataPointIntervalMs / 1000.0);

        final newSpot = FlSpot(_globalTime, newYValue);
        _liveDataSpots1.add(newSpot);

        if (_liveDataSpots1.length > _maxDataPoints) {
          _liveDataSpots1.removeAt(0);
        }
      });
    }
  }

  // Grafik 2 için veri işleme fonksiyonu
  void _handleLiveData2(List<int> value) {
    if (_isGraphRunning && value.length == 4) {
      final byteData = ByteData.sublistView(Uint8List.fromList(value));
      final double newYValue = byteData.getFloat32(0, Endian.little);

      setState(() {
        // _globalTime burada güncellenmez, _handleLiveData1 tarafından güncellenir.
        // Bu, X eksenlerinin senkronize kalmasını sağlar.
        final newSpot = FlSpot(_globalTime, newYValue);
        _liveDataSpots2.add(newSpot);

        if (_liveDataSpots2.length > _maxDataPoints) {
          _liveDataSpots2.removeAt(0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Motor Durumu"),
        backgroundColor: const Color(0xFF161625),
        elevation: 4,
      ),
      body: Column(
        children: [
          // Sayfa Seçim Butonları (taslağa göre üstte)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageButton(0, "MOTOR1"),
                const SizedBox(width: 20), // Butonlar arası boşluk
                _buildPageButton(1, "MOTOR2"),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentPageIndex,
              children: [
                // Her iki sayfa da aynı grafik bileşenini farklı veri listeleriyle gösterecek
                _buildGraphPageContent(
                  _liveDataSpots1,
                ), // Sayfa 1 için _liveDataSpots1 kullan
                _buildGraphPageContent(
                  _liveDataSpots2,
                ), // Sayfa 2 için _liveDataSpots2 kullan
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sayfa butonları için yardımcı widget
  Widget _buildPageButton(int index, String text) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _currentPageIndex = index;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _currentPageIndex == index
            ? Colors.blueAccent
            : Colors.grey[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- Her iki sayfa için de kullanılacak grafik içeriği ---
  // Hangi veri listesini göstereceğini parametre olarak alıyor
  Widget _buildGraphPageContent(List<FlSpot> spotsToDisplay) {
    double minX = 0;
    double maxX = _displaySeconds.toDouble();

    if (spotsToDisplay.isNotEmpty) {
      if (_isGraphRunning) {
        maxX = _globalTime;
        minX = max(0.0, _globalTime - _displaySeconds);

        if (_globalTime < _displaySeconds) {
          minX = 0;
          maxX = _displaySeconds.toDouble();
        }
      } else {
        // Grafik durduysa, kendi spots listesinin min/max X değerlerini kullan
        minX = spotsToDisplay.first.x;
        maxX = spotsToDisplay.last.x;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(
        top: 0.0,
        left: 16.0,
        right: 16.0,
        bottom: 16.0,
      ),
      child: Column(
        children: [
          Expanded(
            child: _buildLiveChart(minX, maxX, spotsToDisplay),
          ), // Görüntülenecek spotları parametre olarak ilet
        ],
      ),
    );
  }

  // Canlı Grafik Oluşturucu Widget'ı
  // minX, maxX ve şimdi de görüntülenecek spotları parametre olarak alıyor
  Widget _buildLiveChart(
    double currentMinX,
    double currentMaxX,
    List<FlSpot> spots,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF161625).withOpacity(0.5),
      ),
      child:
          spots
              .isEmpty // Hangi listeye göre boş kontrolü yapılacaksa o kullanılır
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Veri bekleniyor...',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(right: 20.0, top: 20, bottom: 10),
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 5,
                  minX: currentMinX,
                  maxX: currentMaxX,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 1.0,
                        getTitlesWidget: leftTitleWidgets,
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1.0,
                        getTitlesWidget: bottomTitleWidgets,
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) =>
                        const FlLine(color: Colors.white10, strokeWidth: 1),
                    getDrawingVerticalLine: (value) =>
                        const FlLine(color: Colors.white10, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: const Color(0xff37434d),
                      width: 1,
                    ),
                  ),
                  clipData: const FlClipData.all(),
                  lineBarsData: [
                    LineChartBarData(
                      spots:
                          spots, // Buraya parametre olarak gelen spot listesi kullanılır
                      isCurved: true,
                      color: Colors.cyan,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.cyan.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 0),
              ),
            ),
    );
  }

  // Y ekseni etiketleri için yardımcı fonksiyon (aynı kaldı)
  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    String text;
    if (value.toInt() == value && value >= 1.0 && value <= 5.0) {
      text = value.toInt().toString();
    } else {
      return Container();
    }
    return Text(text, style: style, textAlign: TextAlign.center);
  }

  // X ekseni (saniye) etiketleri için fonksiyon (aynı kaldı)
  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    String text = value.round().toString();
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4.0,
      child: Text(text, style: style),
    );
  }
}
