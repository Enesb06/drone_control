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
  "e6a7b8c9-d0e1-f2a3-b4c5-d6e7f8a9b0c1", // Grafik 2 için
);
// YENİ: Grafik 3 ve 4 için UUID'ler
final Guid timeSeriesCharacteristicUuid3 = Guid(
  "b2f6d0f4-5f80-4a11-b0e5-7b5e43a9f5d3", // Grafik 3 için YENİ
);
final Guid timeSeriesCharacteristicUuid4 = Guid(
  "5e1a7b8c-2d1f-4e0c-9a3d-6c8f4b0e9a72", // Grafik 4 için YENİ
);

class MotorStatusPage extends StatefulWidget {
  final BluetoothDevice device;
  const MotorStatusPage({super.key, required this.device});

  @override
  State<MotorStatusPage> createState() => _MotorStatusPageState();
}

class _MotorStatusPageState extends State<MotorStatusPage> {
  // Grafik veri listeleri (4 adet oldu)
  List<FlSpot> _liveDataSpots1 = []; // Sayfa 1 (Grafik 1) için
  List<FlSpot> _liveDataSpots2 = []; // Sayfa 2 (Grafik 2) için
  List<FlSpot> _liveDataSpots3 = []; // Sayfa 3 (Grafik 3) için YENİ
  List<FlSpot> _liveDataSpots4 = []; // Sayfa 4 (Grafik 4) için YENİ

  // BLE veri abonelikleri (4 adet oldu)
  StreamSubscription<List<int>>? _dataSubscription1; // Grafik 1 için
  StreamSubscription<List<int>>? _dataSubscription2; // Grafik 2 için
  StreamSubscription<List<int>>? _dataSubscription3; // Grafik 3 için YENİ
  StreamSubscription<List<int>>? _dataSubscription4; // Grafik 4 için YENİ
  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  // Global bir zaman sayacı (saniye cinsinden). Veri geldikçe artacak.
  // Her iki grafiğin de X eksenini senkronize etmek için kullanılır.
  double _globalTime = 0;

  // ESP32'den gelen her veri noktasının süresi (ms)
  final int _dataPointIntervalMs =
      100; // <-- KRİTİK: ESP32'deki dataSendInterval ile AYNI OLMALI!

  // Ekranda aynı anda kaç saniyelik veri gösterileceğini belirler (5 saniyelik pencere)
  final int _displaySeconds = 5;
  // Ekranda gösterilecek maksimum nokta sayısı (5 saniye * (1000ms / 10ms_per_point) = 5 * 100 = 500 nokta)
  final int _maxDataPoints =
      500; // <-- KRİTİK: 5 saniyelik pencerede tutulacak nokta sayısı

  Timer? _graphStopTimer;
  final int _graphDurationSeconds = 30; // Grafik 30 saniye sonra duracak

  bool _isGraphRunning = true;

  int _currentPageIndex = 0; // 0: Sayfa1, 1: Sayfa2, 2: Sayfa3, 3: Sayfa4

  @override
  void initState() {
    super.initState();
    _setupPage();
    _startGraphStopTimer();
  }

  @override
  void dispose() {
    // Tüm abonelikleri iptal etmeyi unutma
    _dataSubscription1?.cancel();
    _dataSubscription2?.cancel();
    _dataSubscription3?.cancel(); // YENİ
    _dataSubscription4?.cancel(); // YENİ
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
        // Veri alma aboneliklerini iptal et
        _dataSubscription1?.cancel();
        _dataSubscription2?.cancel();
        _dataSubscription3?.cancel(); // YENİ
        _dataSubscription4?.cancel(); // YENİ
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
            // YENİ: Grafik 3 karakteristik aboneliği
            else if (c.uuid == timeSeriesCharacteristicUuid3) {
              await c.setNotifyValue(true);
              if (_isGraphRunning) {
                _dataSubscription3 = c.onValueReceived.listen(_handleLiveData3);
              }
            }
            // YENİ: Grafik 4 karakteristik aboneliği
            else if (c.uuid == timeSeriesCharacteristicUuid4) {
              await c.setNotifyValue(true);
              if (_isGraphRunning) {
                _dataSubscription4 = c.onValueReceived.listen(_handleLiveData4);
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
        // Global zamanı sadece BİR KERE güncelle (genel senkronizasyon için)
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

  // YENİ: Grafik 3 için veri işleme fonksiyonu
  void _handleLiveData3(List<int> value) {
    if (_isGraphRunning && value.length == 4) {
      final byteData = ByteData.sublistView(Uint8List.fromList(value));
      final double newYValue = byteData.getFloat32(0, Endian.little);

      setState(() {
        final newSpot = FlSpot(_globalTime, newYValue);
        _liveDataSpots3.add(newSpot);

        if (_liveDataSpots3.length > _maxDataPoints) {
          _liveDataSpots3.removeAt(0);
        }
      });
    }
  }

  // YENİ: Grafik 4 için veri işleme fonksiyonu
  void _handleLiveData4(List<int> value) {
    if (_isGraphRunning && value.length == 4) {
      final byteData = ByteData.sublistView(Uint8List.fromList(value));
      final double newYValue = byteData.getFloat32(0, Endian.little);

      setState(() {
        final newSpot = FlSpot(_globalTime, newYValue);
        _liveDataSpots4.add(newSpot);

        if (_liveDataSpots4.length > _maxDataPoints) {
          _liveDataSpots4.removeAt(0);
        }
      });
    }
  }

  // Sayfaların başlıklarını döndüren yardımcı fonksiyon
  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return "MOTOR1 (Tester Sinyali 1)";
      case 1:
        return "MOTOR2 (Tester Sinyali 2)";
      case 2:
        return "MOTOR3 (Tester Sinyali 3)"; // YENİ
      case 3:
        return "MOTOR4 (Tester Sinyali 4)"; // YENİ
      default:
        return "Bilinmeyen Motor";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(_getPageTitle(_currentPageIndex)), // Dinamik başlık
        backgroundColor: const Color(0xFF161625),
        elevation: 4,
      ),
      body: Column(
        children: [
          // Sayfa Seçim Butonları (Şimdi 4 adet)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageButton(0, "MTR1"),
                const SizedBox(width: 8),
                _buildPageButton(1, "MTR2"),
                const SizedBox(width: 8), // Butonlar arası boşluk
                _buildPageButton(2, "MTR3"), // YENİ
                const SizedBox(width: 8),
                _buildPageButton(3, "MTR4"), // YENİ
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentPageIndex,
              children: [
                // Her dört sayfa da aynı grafik bileşenini farklı veri listeleriyle gösterecek
                _buildGraphPageContent(_liveDataSpots1), // Sayfa 1 için
                _buildGraphPageContent(_liveDataSpots2), // Sayfa 2 için
                _buildGraphPageContent(_liveDataSpots3), // Sayfa 3 için YENİ
                _buildGraphPageContent(_liveDataSpots4), // Sayfa 4 için YENİ
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
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ), // Daha küçük butonlar
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ), // Daha küçük yazı
      ),
      child: Text(text),
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

        // İlk saniyelerde X ekseninin 0'dan başlamasını sağlamak için
        if (_globalTime < _displaySeconds) {
          minX = 0;
          maxX = _displaySeconds.toDouble();
        }
      } else {
        // Grafik durduysa, kendi spots listesinin min/max X değerlerini kullan
        // Bu durumda son 5 saniyelik veriyi göstermeli
        if (spotsToDisplay.length > _maxDataPoints) {
          minX = spotsToDisplay[spotsToDisplay.length - _maxDataPoints].x;
        } else {
          minX = spotsToDisplay.first.x;
        }
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
      child: spots.isEmpty
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
                  minY: 0, // Tüm sinyaller 0-5 arasında olduğu için uygun
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
    if (value.toInt() == value && value >= 0.0 && value <= 5.0) {
      // Y ekseni 0'dan başladı
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
