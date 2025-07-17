import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:uptime_monitor_final/recorded_session.dart';

class ViewRecordedGraphPage extends StatefulWidget {
  final RecordedSession session;

  const ViewRecordedGraphPage({Key? key, required this.session})
    : super(key: key);

  @override
  _ViewRecordedGraphPageState createState() => _ViewRecordedGraphPageState();
}

class _ViewRecordedGraphPageState extends State<ViewRecordedGraphPage> {
  int _selectedIndex = 0;

  late double _minX, _maxX, _minY, _maxY;
  late double _initialMinX, _initialMaxX, _initialMinY, _initialMaxY;

  double _gestureStartMinX = 0, _gestureStartMaxX = 0;
  double _gestureStartMinY = 0, _gestureStartMaxY = 0;

  final double _panSensitivity = 1.0;
  final double _zoomSensitivity = 1.0;

  @override
  void initState() {
    super.initState();
    _setupInitialBoundaries();
  }

  @override
  void didUpdateWidget(covariant ViewRecordedGraphPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.id != oldWidget.session.id) {
      _setupInitialBoundaries();
    }
  }

  void _setupInitialBoundaries() {
    final allData = _getAllDataPoints();
    if (allData.isEmpty) {
      _initialMinX = 0;
      _initialMaxX = 30;
      _initialMinY = 0;
      _initialMaxY = 100;
    } else {
      _initialMinX = allData.map((e) => e.x).reduce(min);
      _initialMaxX = allData.map((e) => e.x).reduce(max);
      _initialMinY = allData.map((e) => e.y).reduce(min);
      _initialMaxY = allData.map((e) => e.y).reduce(max);

      final xPadding = (_initialMaxX - _initialMinX) * 0.05;
      final yPadding = (_initialMaxY - _initialMinY) * 0.1;
      _initialMinX -= xPadding;
      _initialMaxX += xPadding;
      _initialMinY -= yPadding;
      _initialMaxY += yPadding;
    }
    _resetZoom();
  }

  List<FlSpot> _getAllDataPoints() {
    return [
      ...widget.session.motor1Data,
      ...widget.session.motor2Data,
      ...widget.session.motor3Data,
      ...widget.session.motor4Data,
    ];
  }

  List<FlSpot> get _selectedMotorData {
    switch (_selectedIndex) {
      case 0:
        return widget.session.motor1Data;
      case 1:
        return widget.session.motor2Data;
      case 2:
        return widget.session.motor3Data;
      case 3:
        return widget.session.motor4Data;
      default:
        return [];
    }
  }

  void _resetZoom() {
    setState(() {
      _minX = _initialMinX;
      _maxX = _initialMaxX;
      _minY = _initialMinY;
      _maxY = _initialMaxY;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(
          'Oturum: ${widget.session.timestamp.toLocal().toString().substring(0, 16)}',
        ),
        backgroundColor: const Color(0xFF161625),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            tooltip: "Görünümü Sıfırla",
            onPressed: _resetZoom,
          ),
        ],
      ),
      body: _selectedMotorData.isEmpty
          ? const Center(
              child: Text(
                "Bu oturum için veri bulunamadı.",
                style: TextStyle(color: Colors.white54),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onScaleStart: (details) {
                      _gestureStartMinX = _minX;
                      _gestureStartMaxX = _maxX;
                      _gestureStartMinY = _minY;
                      _gestureStartMaxY = _maxY;
                    },
                    onScaleUpdate: (details) {
                      if (context.size == null) return;
                      final gestureXRange =
                          _gestureStartMaxX - _gestureStartMinX;
                      final gestureYRange =
                          _gestureStartMaxY - _gestureStartMinY;
                      final newXRange =
                          gestureXRange / (details.scale * _zoomSensitivity);
                      final newYRange =
                          gestureYRange / (details.scale * _zoomSensitivity);
                      final dx =
                          details.focalPointDelta.dx *
                          (gestureXRange / context.size!.width) *
                          _panSensitivity;
                      final dy =
                          details.focalPointDelta.dy *
                          (gestureYRange / context.size!.height) *
                          _panSensitivity;
                      final newMinX =
                          _gestureStartMinX -
                          dx -
                          (newXRange - gestureXRange) / 2;
                      final newMaxX = newMinX + newXRange;
                      final newMinY =
                          _gestureStartMinY +
                          dy -
                          (newYRange - gestureYRange) / 2;
                      final newMaxY = newMinY + newYRange;
                      setState(() {
                        if ((newMaxX - newMinX) <
                                (_initialMaxX - _initialMinX) * 5 &&
                            (newMaxX - newMinX) > 0.01) {
                          _minX = newMinX;
                          _maxX = newMaxX;
                        }
                        if ((newMaxY - newMinY) <
                                (_initialMaxY - _initialMinY) * 5 &&
                            (newMaxY - newMinY) > 0.01) {
                          _minY = newMinY;
                          _maxY = newMaxY;
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LineChart(
                        _buildInteractiveChartData(),
                        duration: Duration.zero,
                      ),
                    ),
                  ),
                ),
                _buildMotorSelector(),
              ],
            ),
    );
  }

  // ============== TEK DEĞİŞİKLİK BU METODUN İÇİNDE ==============
  LineChartData _buildInteractiveChartData() {
    // === LİDERİN DOKUNUŞU: TUTARLILIK SAĞLANDI ===
    // 1. Toplam kayıt süresini alıyoruz.
    // Kaydedilen verinin son noktasının 'x' değeri bize toplam süreyi verir.
    double totalDuration = 0;
    if (_selectedMotorData.isNotEmpty) {
      totalDuration = _selectedMotorData.last.x;
    }

    // 2. Tıpkı canlı grafikteki gibi, X ekseni aralığını hesaplıyoruz.
    // Toplam süreyi 5'e bölerek "akıllı" aralığı buluyoruz.
    double bottomTitleInterval = totalDuration / 5.0;

    // 3. Güvenlik kontrolü: Eğer süre çok kısa veya 0 ise,
    // varsayılan bir aralık kullan.
    if (bottomTitleInterval <= 0) {
      bottomTitleInterval = 1.0;
    }
    // ==========================================================

    return LineChartData(
      minX: _minX,
      maxX: _maxX,
      minY: _minY,
      maxY: _maxY,
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
        ),
      ),
      gridData: FlGridData(
        show: true,
        getDrawingHorizontalLine: (value) =>
            const FlLine(color: Colors.white12, strokeWidth: 0.5),
        getDrawingVerticalLine: (value) =>
            const FlLine(color: Colors.white12, strokeWidth: 0.5),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(0),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            // 4. Dinamik olarak hesapladığımız aralığı burada kullanıyoruz.
            interval: bottomTitleInterval,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(0),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.white24),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: _selectedMotorData,
          isCurved: true,
          color: Colors.tealAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.tealAccent.withOpacity(0.2),
          ),
        ),
      ],
    );
  }

  Widget _buildMotorSelector() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
          _resetZoom(); // Motor değiştirildiğinde zoom'u sıfırla
        });
      },
      backgroundColor: const Color(0xFF161625),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.developer_board_outlined),
          activeIcon: Icon(Icons.developer_board),
          label: "Motor 1",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.developer_board_outlined),
          activeIcon: Icon(Icons.developer_board),
          label: "Motor 2",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.developer_board_outlined),
          activeIcon: Icon(Icons.developer_board),
          label: "Motor 3",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.developer_board_outlined),
          activeIcon: Icon(Icons.developer_board),
          label: "Motor 4",
        ),
      ],
      selectedItemColor: Colors.tealAccent,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
    );
  }
}
