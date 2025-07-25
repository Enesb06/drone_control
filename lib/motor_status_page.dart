import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
// Projenizin yapısına göre import yolunu kontrol edin.
import 'package:uptime_monitor_final/recorded_session.dart';
import 'package:uptime_monitor_final/settings_service.dart';

// ----- UUID'ler -----
final Guid serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
final Guid timeSeriesCharacteristicUuid1 = Guid(
  "c1d2e3f4-a5b6-c7d8-e9f0-a1b2c3d4e5f6",
);
final Guid timeSeriesCharacteristicUuid2 = Guid(
  "e6a7b8c9-d0e1-f2a3-b4c5-d6e7f8a9b0c1",
);
final Guid timeSeriesCharacteristicUuid3 = Guid(
  "b2f6d0f4-5f80-4a11-b0e5-7b5e43a9f5d3",
);
final Guid timeSeriesCharacteristicUuid4 = Guid(
  "5e1a7b8c-2d1f-4e0c-9a3d-6c8f4b0e9a72",
);

// Veri Tipi Seçimi için Enum
enum DataType { x_axis, y_axis, z_axis, resultant }

// YENİ ENUM: Motor durumunu belirtmek için
enum MotorStatus { normal, outOfBounds }

class MotorStatusPage extends StatefulWidget {
  final BluetoothDevice device;
  const MotorStatusPage({super.key, required this.device});

  @override
  State<MotorStatusPage> createState() => _MotorStatusPageState();
}

class _MotorStatusPageState extends State<MotorStatusPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  DataType _selectedDataType = DataType.resultant;
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
  final int _dataPointIntervalMs = 100;
  final int _displaySeconds = 5;
  Timer? _graphStopTimer;
  final int _graphDurationSeconds = 60;
  bool _isGraphRunning = true;
  bool _isSavingData = false;
  bool _dataSaved = false;

  bool _isMenuVisible = true;
  final double _menuWidth = 100.0;

  // ===== YENİ STATE DEĞİŞKENLERİ =====
  final _settingsService = SettingsService();
  late double _minValue;
  late double _maxValue;

  // Her motor için ayrı durum takibi
  MotorStatus _motor1Status = MotorStatus.normal;
  MotorStatus _motor2Status = MotorStatus.normal;
  MotorStatus _motor3Status = MotorStatus.normal;
  MotorStatus _motor4Status = MotorStatus.normal;
  // ===================================

  @override
  void initState() {
    super.initState();
    _loadSettings(); // Ayarları yükle
    _tabController = TabController(length: 4, vsync: this);
    _setupPage();
    _startGraphStopTimer();
  }

  // YENİ FONKSİYON: Ayarları hafızadan okur
  void _loadSettings() {
    setState(() {
      _minValue = _settingsService.getMinValue();
      _maxValue = _settingsService.getMaxValue();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dataSubscription1?.cancel();
    _dataSubscription2?.cancel();
    _dataSubscription3?.cancel();
    _dataSubscription4?.cancel();
    _connectionSub?.cancel();
    _graphStopTimer?.cancel();
    super.dispose();
  }

  // ==========================================================
  // YENİ EKLENEN KOD BÖLÜMÜ
  // ==========================================================

  /// Akışı manuel olarak durdurur ve kullanıcıya kaydetme seçeneği sunar.
  void _stopRecordingAndPromptSave() {
    if (!_isGraphRunning) return; // Zaten durmuşsa işlem yapma

    // Otomatik durdurma sayacını iptal et
    _graphStopTimer?.cancel();

    // Veri aboneliklerini iptal et
    _dataSubscription1?.cancel();
    _dataSubscription2?.cancel();
    _dataSubscription3?.cancel();
    _dataSubscription4?.cancel();

    // Akışı ve grafiği durdur
    setState(() {
      _isGraphRunning = false;
    });

    // Kaydetme dialog'unu göster
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSaveSessionDialog();
    });
  }

  /// Kullanıcıya oturumu kaydetmek isteyip istemediğini soran dialog'u gösterir.
  Future<void> _showSaveSessionDialog() async {
    // Eğer hiç veri toplanmamışsa, sormaya gerek yok.
    if (_liveDataSpots1.isEmpty &&
        _liveDataSpots2.isEmpty &&
        _liveDataSpots3.isEmpty &&
        _liveDataSpots4.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt durduruldu. Kaydedilecek veri yok.'),
          ),
        );
      }
      return;
    }

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Kullanıcı bir seçim yapmak zorunda
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            'Oturumu Kaydet',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Bu kayıt oturumunu kaydetmek istiyor musunuz?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Kaydetme',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              child: const Text('Kaydet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 247, 247, 248),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldSave == true) {
      _saveGraphData(); // Mevcut kaydetme fonksiyonunu çağır
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Oturum kaydedilmedi.')));
      }
    }
  }

  // ==========================================================
  // MEVCUT KOD (DEĞİŞİKLİK YOK)
  // ==========================================================

  void _toggleMenuVisibility() {
    setState(() {
      _isMenuVisible = !_isMenuVisible;
    });
  }

  String _getSelectedDataTypeText() {
    switch (_selectedDataType) {
      case DataType.x_axis:
        return "Veri Tipi: X Ekseni";
      case DataType.y_axis:
        return "Veri Tipi: Y Ekseni";
      case DataType.z_axis:
        return "Veri Tipi: Z Ekseni";
      case DataType.resultant:
        return "Veri Tipi: Bileşke";
    }
  }

  void _startGraphStopTimer() {
    _graphStopTimer = Timer(Duration(seconds: _graphDurationSeconds), () {
      if (mounted && _isGraphRunning) {
        // Otomatik durdurma tetiklendiğinde abonelikleri iptal et
        _dataSubscription1?.cancel();
        _dataSubscription2?.cancel();
        _dataSubscription3?.cancel();
        _dataSubscription4?.cancel();

        setState(() {
          _isGraphRunning = false;
        });

        if (!_dataSaved) {
          _saveGraphData();
        }
      }
    });
  }

  Future<void> _saveGraphData() async {
    if (_isSavingData || _dataSaved) return;
    setState(() => _isSavingData = true);
    try {
      final now = DateTime.now();
      final String sessionId = now.millisecondsSinceEpoch.toString();
      final session = RecordedSession(
        id: sessionId,
        timestamp: now,
        motor1Data: List.from(_liveDataSpots1),
        motor2Data: List.from(_liveDataSpots2),
        motor3Data: List.from(_liveDataSpots3),
        motor4Data: List.from(_liveDataSpots4),
      );
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'session_${session.id}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonEncode(session.toJson()));

      if (mounted) {
        setState(() {
          _isSavingData = false;
          _dataSaved = true;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Grafik kaydedildi: $fileName')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingData = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _setupPage() async {
    _connectionSub = widget.device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && mounted) {
        Navigator.of(context).pop();
      }
    });
    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      for (var s in services) {
        if (s.uuid == serviceUuid) {
          for (var c in s.characteristics) {
            if (c.uuid == timeSeriesCharacteristicUuid1) {
              await c.setNotifyValue(true);
              if (_isGraphRunning)
                _dataSubscription1 = c.onValueReceived.listen(_handleLiveData1);
            } else if (c.uuid == timeSeriesCharacteristicUuid2) {
              await c.setNotifyValue(true);
              if (_isGraphRunning)
                _dataSubscription2 = c.onValueReceived.listen(_handleLiveData2);
            } else if (c.uuid == timeSeriesCharacteristicUuid3) {
              await c.setNotifyValue(true);
              if (_isGraphRunning)
                _dataSubscription3 = c.onValueReceived.listen(_handleLiveData3);
            } else if (c.uuid == timeSeriesCharacteristicUuid4) {
              await c.setNotifyValue(true);
              if (_isGraphRunning)
                _dataSubscription4 = c.onValueReceived.listen(_handleLiveData4);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Servis keşfi hatası: $e')));
        Navigator.of(context).pop();
      }
    }
  }

  void _handleLiveData1(List<int> value) {
    if (!_isGraphRunning || value.length != 4) return;
    final byteData = ByteData.sublistView(Uint8List.fromList(value));
    final double newYValue = byteData.getFloat32(0, Endian.little);

    // YENİ: Eşik kontrolü
    final newStatus = (newYValue >= _minValue && newYValue <= _maxValue)
        ? MotorStatus.normal
        : MotorStatus.outOfBounds;

    setState(() {
      _globalTime += (_dataPointIntervalMs / 1000.0);
      final newSpot = FlSpot(_globalTime, newYValue);
      _liveDataSpots1.add(newSpot);
      if (_motor1Status != newStatus) {
        _motor1Status = newStatus;
      }
    });
  }

  void _handleLiveData2(List<int> value) {
    if (!_isGraphRunning || value.length != 4) return;
    final byteData = ByteData.sublistView(Uint8List.fromList(value));
    final double newYValue = byteData.getFloat32(0, Endian.little);
    final newStatus = (newYValue >= _minValue && newYValue <= _maxValue)
        ? MotorStatus.normal
        : MotorStatus.outOfBounds;

    setState(() {
      final newSpot = FlSpot(_globalTime, newYValue);
      _liveDataSpots2.add(newSpot);
      if (_motor2Status != newStatus) {
        _motor2Status = newStatus;
      }
    });
  }

  void _handleLiveData3(List<int> value) {
    if (!_isGraphRunning || value.length != 4) return;
    final byteData = ByteData.sublistView(Uint8List.fromList(value));
    final double newYValue = byteData.getFloat32(0, Endian.little);
    final newStatus = (newYValue >= _minValue && newYValue <= _maxValue)
        ? MotorStatus.normal
        : MotorStatus.outOfBounds;
    setState(() {
      final newSpot = FlSpot(_globalTime, newYValue);
      _liveDataSpots3.add(newSpot);
      if (_motor3Status != newStatus) {
        _motor3Status = newStatus;
      }
    });
  }

  void _handleLiveData4(List<int> value) {
    if (!_isGraphRunning || value.length != 4) return;
    final byteData = ByteData.sublistView(Uint8List.fromList(value));
    final double newYValue = byteData.getFloat32(0, Endian.little);
    final newStatus = (newYValue >= _minValue && newYValue <= _maxValue)
        ? MotorStatus.normal
        : MotorStatus.outOfBounds;
    setState(() {
      final newSpot = FlSpot(_globalTime, newYValue);
      _liveDataSpots4.add(newSpot);
      if (_motor4Status != newStatus) {
        _motor4Status = newStatus;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("MOTOR ${_tabController.index + 1}"),
            if (!_isMenuVisible)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  _getSelectedDataTypeText(),
                  style: const TextStyle(
                    fontSize: 12.0,
                    color: Colors.white70,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF161625),
        elevation: 2,
        actions: [
          if (_isGraphRunning)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: _stopRecordingAndPromptSave,
              tooltip: 'Kaydı Durdur',
            ),
          if (!_dataSaved && !_isSavingData && !_isGraphRunning)
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
        // TabBar'ı durum göstergeleriyle güncelliyoruz
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          indicatorWeight: 3.0,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          onTap: (index) {
            setState(() {});
          },
          tabs: [
            _buildMotorTab("M1", _motor1Status),
            _buildMotorTab("M2", _motor2Status),
            _buildMotorTab("M3", _motor3Status),
            _buildMotorTab("M4", _motor4Status),
          ],
        ),
      ),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: _isMenuVisible ? _menuWidth : 0,
            child: ClipRect(child: _buildDataTypeSelectorMenu()),
          ),
          GestureDetector(
            onTap: _toggleMenuVisibility,
            child: Container(
              width: 20,
              height: double.infinity,
              color: const Color(0xFF161625).withOpacity(0.5),
              child: Icon(
                _isMenuVisible
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _tabController,
                    children: [
                      _buildGraphPageContent(_liveDataSpots1),
                      _buildGraphPageContent(_liveDataSpots2),
                      _buildGraphPageContent(_liveDataSpots3),
                      _buildGraphPageContent(_liveDataSpots4),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Colors.white24),
                Expanded(
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _tabController,
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
          ),
        ],
      ),
    );
  }

  // YENİ WIDGET: Motor sekmesini durum göstergesiyle birlikte oluşturan fonksiyon
  Widget _buildMotorTab(String title, MotorStatus status) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: status == MotorStatus.normal
                  ? Colors.greenAccent
                  : Colors.redAccent,
              boxShadow: [
                BoxShadow(
                  color:
                      (status == MotorStatus.normal
                              ? Colors.greenAccent
                              : Colors.redAccent)
                          .withOpacity(0.7),
                  blurRadius: 4.0,
                  spreadRadius: 1.0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTypeSelectorMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      constraints: BoxConstraints(maxWidth: _menuWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Motor ${_tabController.index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
          const SizedBox(height: 8),
          const Text(
            'Veri Tipi',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Divider(color: Colors.white24, height: 12, thickness: 0.5),
          _buildRadioOption(DataType.x_axis, "X Ekseni"),
          _buildRadioOption(DataType.y_axis, "Y Ekseni"),
          _buildRadioOption(DataType.z_axis, "Z Ekseni"),
          _buildRadioOption(DataType.resultant, "Bileşke"),
        ],
      ),
    );
  }

  Widget _buildRadioOption(DataType value, String title) {
    return InkWell(
      onTap: () => setState(() => _selectedDataType = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Radio<DataType>(
              value: value,
              groupValue: _selectedDataType,
              onChanged: (DataType? newValue) {
                if (newValue != null)
                  setState(() => _selectedDataType = newValue);
              },
              activeColor: Colors.cyanAccent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(
                horizontal: VisualDensity.minimumDensity,
                vertical: VisualDensity.minimumDensity,
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: _selectedDataType == value
                      ? Colors.white
                      : Colors.white70,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphPageContent(List<FlSpot> spotsToDisplay) {
    double minX, maxX;
    if (spotsToDisplay.isNotEmpty) {
      if (_isGraphRunning) {
        maxX = _globalTime;
        minX = max(0.0, _globalTime - _displaySeconds);
      } else {
        minX = 0.0;
        maxX = _globalTime > 0 ? _globalTime : _graphDurationSeconds.toDouble();
      }
    } else {
      minX = 0.0;
      maxX = _displaySeconds.toDouble();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 20, top: 24, bottom: 12),
      child: _buildLiveChart(minX, maxX, spotsToDisplay),
    );
  }

  Widget _buildLiveChart(
    double currentMinX,
    double currentMaxX,
    List<FlSpot> spots,
  ) {
    double bottomTitleInterval;
    double effectiveMaxX = _isGraphRunning
        ? currentMaxX
        : (_globalTime > 0 ? _globalTime : _graphDurationSeconds.toDouble());

    if (_isGraphRunning) {
      bottomTitleInterval = 1.0;
    } else {
      bottomTitleInterval = max(1.0, effectiveMaxX / 5.0);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF161625).withOpacity(0.5),
      ),
      child: spots.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isGraphRunning) const CircularProgressIndicator(),
                  if (_isGraphRunning) const SizedBox(height: 16),
                  Text(
                    _isGraphRunning
                        ? 'Veri bekleniyor...'
                        : 'Kayıt durduruldu.',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            )
          : LineChart(
              LineChartData(
                minY: 0,
                maxY: 5,
                minX: currentMinX,
                maxX: currentMaxX,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1.0,
                      getTitlesWidget: (v, m) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: bottomTitleInterval,
                      getTitlesWidget: (v, m) => Text(
                        v.round().toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (value) =>
                      const FlLine(color: Colors.white10, strokeWidth: 0.5),
                  getDrawingVerticalLine: (value) =>
                      const FlLine(color: Colors.white10, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.cyan,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.cyan.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
              duration: Duration.zero,
            ),
    );
  }
}
