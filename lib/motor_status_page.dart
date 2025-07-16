import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math'; // max fonksiyonu için
import 'dart:convert'; // JSON işlemleri için
import 'dart:io'; // Dosya işlemleri için
import 'package:path_provider/path_provider.dart'; // Dosya yolunu bulmak için
import 'package:uptime_monitor_final/recorded_session.dart'; // Yeni veri modelini import edin (uygulama adınıza göre yolu ayarlayın)

// ----- KULLANACAĞIMIZ UUID'LER (ESP32 İLE AYNI OLMALI) -----
final Guid serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
final Guid timeSeriesCharacteristicUuid1 = Guid(
  "c1d2e3f4-a5b6-c7d8-e9f0-a1b2c3d4e5f6", // Grafik 1 için
);
final Guid timeSeriesCharacteristicUuid2 = Guid(
  "e6a7b8c9-d0e1-f2a3-b4c5-d6e7f8a9b0c1", // Grafik 2 için
);
final Guid timeSeriesCharacteristicUuid3 = Guid(
  "b2f6d0f4-5f80-4a11-b0e5-7b5e43a9f5d3", // Grafik 3 için
);
final Guid timeSeriesCharacteristicUuid4 = Guid(
  "5e1a7b8c-2d1f-4e0c-9a3d-6c8f4b0e9a72", // Grafik 4 için
);

class MotorStatusPage extends StatefulWidget {
  final BluetoothDevice device;
  const MotorStatusPage({super.key, required this.device});

  @override
  State<MotorStatusPage> createState() => _MotorStatusPageState();
}

class _MotorStatusPageState extends State<MotorStatusPage> {
  // ... (Mevcut değişkenleriniz aynı kalacak) ...

  List<FlSpot> _liveDataSpots1 = [];
  List<FlSpot> _liveDataSpots2 = [];
  List<FlSpot> _liveDataSpots3 = [];
  List<FlSpot> _liveDataSpots4 = [];

  StreamSubscription<List<int>>? _dataSubscription1;
  StreamSubscription<List<int>>? _dataSubscription2;
  StreamSubscription<List<int>>? _dataSubscription3;
  StreamSubscription<List<int>>? _dataSubscription4;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  double _globalTime = 0;
  final int _dataPointIntervalMs = 100; // 10ms'den 100ms'ye yükseltildi
  final int _displaySeconds = 5;
  final int _maxDataPoints = 500;

  Timer? _graphStopTimer;
  final int _graphDurationSeconds = 30;

  bool _isGraphRunning = true;
  bool _isSavingData = false; // Veri kaydetme durumu
  bool _dataSaved = false; // Veri kaydedildi mi?

  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _setupPage();
    _startGraphStopTimer();
  }

  @override
  void dispose() {
    _dataSubscription1?.cancel();
    _dataSubscription2?.cancel();
    _dataSubscription3?.cancel();
    _dataSubscription4?.cancel();
    _connectionSub?.cancel();
    _graphStopTimer?.cancel();
    super.dispose();
  }

  void _startGraphStopTimer() {
    _graphStopTimer = Timer(Duration(seconds: _graphDurationSeconds), () {
      if (mounted) {
        setState(() {
          _isGraphRunning = false;
        });
        _dataSubscription1?.cancel();
        _dataSubscription2?.cancel();
        _dataSubscription3?.cancel();
        _dataSubscription4?.cancel();
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

        // Grafik durduğunda otomatik kaydet
        if (!_dataSaved) {
          _saveGraphData();
        }
      }
    });
  }

  // --- YENİ KAYDETME FONKSİYONU ---
  Future<void> _saveGraphData() async {
    if (_isSavingData || _dataSaved)
      return; // Zaten kaydediliyorsa veya kaydedildiyse tekrar etme

    setState(() {
      _isSavingData = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fileName =
          'session_${now.toIso8601String().replaceAll(':', '-')}.json';
      final file = File('${directory.path}/$fileName');

      final session = RecordedSession(
        id: now.toIso8601String(),
        timestamp: now,
        motor1Data: List.from(_liveDataSpots1), // Kopya al
        motor2Data: List.from(_liveDataSpots2),
        motor3Data: List.from(_liveDataSpots3),
        motor4Data: List.from(_liveDataSpots4),
      );

      final jsonString = jsonEncode(session.toJson());
      await file.writeAsString(jsonString);

      setState(() {
        _isSavingData = false;
        _dataSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Grafik verisi kaydedildi: $fileName')),
      );
      print('Grafik verisi kaydedildi: ${file.path}');
    } catch (e) {
      setState(() {
        _isSavingData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veri kaydederken hata oluştu: $e')),
      );
      print('Veri kaydederken hata oluştu: $e');
    }
  }

  // ... (Mevcut _setupPage, _handleLiveData1, _handleLiveData2, _handleLiveData3, _handleLiveData4 fonksiyonları aynı kalacak) ...
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
            if (c.uuid == timeSeriesCharacteristicUuid1) {
              await c.setNotifyValue(true);
              // Sadece _isGraphRunning true ise dinlemeye başla
              if (_isGraphRunning) {
                _dataSubscription1 = c.onValueReceived.listen(_handleLiveData1);
              }
            } else if (c.uuid == timeSeriesCharacteristicUuid2) {
              await c.setNotifyValue(true);
              if (_isGraphRunning) {
                _dataSubscription2 = c.onValueReceived.listen(_handleLiveData2);
              }
            } else if (c.uuid == timeSeriesCharacteristicUuid3) {
              await c.setNotifyValue(true);
              if (_isGraphRunning) {
                _dataSubscription3 = c.onValueReceived.listen(_handleLiveData3);
              }
            } else if (c.uuid == timeSeriesCharacteristicUuid4) {
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

  void _handleLiveData1(List<int> value) {
    if (_isGraphRunning && value.length == 4) {
      final byteData = ByteData.sublistView(Uint8List.fromList(value));
      final double newYValue = byteData.getFloat32(0, Endian.little);

      setState(() {
        _globalTime += (_dataPointIntervalMs / 1000.0);
        final newSpot = FlSpot(_globalTime, newYValue);
        _liveDataSpots1.add(newSpot);

        if (_liveDataSpots1.length > _maxDataPoints) {
          _liveDataSpots1.removeAt(0);
        }
      });
    }
  }

  void _handleLiveData2(List<int> value) {
    if (_isGraphRunning && value.length == 4) {
      final byteData = ByteData.sublistView(Uint8List.fromList(value));
      final double newYValue = byteData.getFloat32(0, Endian.little);

      setState(() {
        final newSpot = FlSpot(_globalTime, newYValue);
        _liveDataSpots2.add(newSpot);

        if (_liveDataSpots2.length > _maxDataPoints) {
          _liveDataSpots2.removeAt(0);
        }
      });
    }
  }

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

  // ... (Mevcut _getPageTitle fonksiyonu aynı kalacak) ...
  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return "MOTOR1 (Tester Sinyali 1)";
      case 1:
        return "MOTOR2 (Tester Sinyali 2)";
      case 2:
        return "MOTOR3 (Sinüs Dalgası)";
      case 3:
        return "MOTOR4 (Kare Dalga)";
      default:
        return "Bilinmeyen Motor";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(_getPageTitle(_currentPageIndex)),
        backgroundColor: const Color(0xFF161625),
        elevation: 4,
        actions: [
          // YENİ: Kaydet Butonu
          if (!_dataSaved &&
              !_isSavingData &&
              !_isGraphRunning) // Sadece grafik durduysa ve kaydedilmediyse göster
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveGraphData,
              tooltip: 'Grafik Verisini Kaydet',
            ),
          if (_isSavingData)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
      body: Column(
        children: [
          // ... (Mevcut sayfa seçim butonları aynı kalacak) ...
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageButton(0, "MTR1"),
                const SizedBox(width: 8),
                _buildPageButton(1, "MTR2"),
                const SizedBox(width: 8),
                _buildPageButton(2, "MTR3"),
                const SizedBox(width: 8),
                _buildPageButton(3, "MTR4"),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentPageIndex,
              children: [
                _buildGraphPageContent(_liveDataSpots1),
                _buildGraphPageContent(_liveDataSpots2),
                _buildGraphPageContent(_liveDataSpots3),
                _buildGraphPageContent(_liveDataSpots4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ... (Geri kalan _buildPageButton, _buildGraphPageContent, _buildLiveChart, leftTitleWidgets, bottomTitleWidgets fonksiyonları aynı kalacak) ...
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      child: Text(text),
    );
  }

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
          Expanded(child: _buildLiveChart(minX, maxX, spotsToDisplay)),
        ],
      ),
    );
  }

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
                      spots: spots,
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

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    String text;
    if (value.toInt() == value && value >= 0.0 && value <= 5.0) {
      text = value.toInt().toString();
    } else {
      return Container();
    }
    return Text(text, style: style, textAlign: TextAlign.center);
  }

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
