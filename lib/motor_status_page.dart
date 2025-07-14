import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math'; // max fonksiyonu için

// Sadece kullanacağımız UUID'ler
final Guid serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
final Guid timeSeriesCharacteristicUuid = Guid(
  "c1d2e3f4-a5b6-c7d8-e9f0-a1b2c3d4e5f6",
);

class MotorStatusPage extends StatefulWidget {
  final BluetoothDevice device;
  const MotorStatusPage({super.key, required this.device});

  @override
  State<MotorStatusPage> createState() => _MotorStatusPageState();
}

class _MotorStatusPageState extends State<MotorStatusPage> {
  List<FlSpot> _liveDataSpots = [];
  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  // Global bir zaman sayacı (saniye cinsinden). Veri geldikçe artacak.
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

  @override
  void initState() {
    super.initState();
    _setupPage();
    _startGraphStopTimer();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
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
        _dataSubscription?.cancel(); // Veri alma aboneliğini iptal et
        print(
          "Grafik 30 saniye dolduğu için durduruldu. Son ${_displaySeconds} saniye gösteriliyor.",
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Grafik 30sn doldu. Son ${_displaySeconds}sn gösteriliyor.',
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
            if (c.uuid == timeSeriesCharacteristicUuid) {
              await c.setNotifyValue(true);
              if (_isGraphRunning) {
                _dataSubscription = c.onValueReceived.listen(_handleLiveData);
              }
              break;
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

  void _handleLiveData(List<int> value) {
    if (_isGraphRunning && value.length == 4) {
      final byteData = ByteData.sublistView(Uint8List.fromList(value));
      final double newYValue = byteData.getFloat32(0, Endian.little);

      setState(() {
        _globalTime +=
            (_dataPointIntervalMs /
            1000.0); // Ms'yi saniyeye çevirerek global zamanı artır

        final newSpot = FlSpot(_globalTime, newYValue);
        _liveDataSpots.add(newSpot);

        // Her zaman sadece son _maxDataPoints'i (500 nokta = 5 saniye) tut
        if (_liveDataSpots.length > _maxDataPoints) {
          _liveDataSpots.removeAt(0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double minX = 0;
    double maxX = _displaySeconds.toDouble(); // Varsayılan 0-5 saniye pencere

    if (_liveDataSpots.isNotEmpty) {
      if (_isGraphRunning) {
        // Grafik akarken, X ekseni penceresini mutlak zamana göre kaydır
        maxX = _globalTime;
        minX = max(0.0, _globalTime - _displaySeconds); // minX negatif olmasın

        // Başlangıçta (ilk _displaySeconds boyunca) pencereyi doldurma efekti için
        if (_globalTime < _displaySeconds) {
          minX = 0;
          maxX = _displaySeconds.toDouble();
        }
      } else {
        // Grafik durduysa, son 5 saniyelik pencereyi sabit tut
        minX = _liveDataSpots.first.x;
        maxX = _liveDataSpots.last.x;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Canlı Veri Akış Testi"),
        backgroundColor: const Color(0xFF161625),
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'ESP32\'den Gelen Canlı Veri',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isGraphRunning
                  ? 'ESP32\'den rastgele sayılar akmaktadır. Grafik 30 saniye sonra duracak ve son 5 saniyeyi gösterecektir.'
                  : 'Grafik 30 saniye dolduğu için durdurulmuştur. Son 5 saniye gösteriliyor.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildLiveChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveChart() {
    // currentMinX ve currentMaxX değerleri dışarıdaki _buildLiveChart() metodu içinde hesaplanıyor.
    // Buradaki geçici tanımlar sadece Scope (kapsam) nedeniyle.
    // Asıl değerler LineChartData'ya iletiliyor.
    double currentMinX = 0;
    double currentMaxX = _displaySeconds.toDouble();

    if (_liveDataSpots.isNotEmpty) {
      if (_isGraphRunning) {
        currentMaxX = _globalTime;
        currentMinX = max(0.0, _globalTime - _displaySeconds);

        if (_globalTime < _displaySeconds) {
          currentMinX = 0;
          currentMaxX = _displaySeconds.toDouble();
        }
      } else {
        currentMinX = _liveDataSpots.first.x;
        currentMaxX = _liveDataSpots.last.x;
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF161625).withOpacity(0.5),
      ),
      child: _liveDataSpots.isEmpty
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
                        interval: 1.0, // <-- Her 1 saniyede bir etiket
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
                      spots: _liveDataSpots,
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

  // Y ekseni etiketleri için yardımcı fonksiyon (1, 2, 3, 4, 5 olarak gösterilecek)
  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    String text;
    // Sadece tam sayı değerlerinde ve 1.0 ile 5.0 arasındaki değerleri gösteriyoruz
    if (value.toInt() == value && value >= 1.0 && value <= 5.0) {
      text = value.toInt().toString(); // Tam sayı olarak göster
    } else {
      return Container();
    }
    return Text(text, style: style, textAlign: TextAlign.center);
  }

  // X ekseni (saniye) etiketleri için fonksiyon (mutlak saniye değerlerini gösterecek)
  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    // value, X eksenindeki mutlak saniyeyi temsil eder.
    // Bu değeri yuvarlayarak tam saniyeyi alıyoruz.
    String text = value.round().toString();

    // Yalnızca tam saniye değerleri için etiket göster
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4.0,
      child: Text(text, style: style),
    );
  }
}
