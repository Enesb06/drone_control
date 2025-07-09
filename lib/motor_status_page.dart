import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart'; // YENİ: Grafik paketini import et

// --- VERİ MODELLERİ GRAFİK VERİLERİ İÇİN GÜNCELLENDİ ---

// Tek bir eksenin tüm verilerini tutacak model
class AxisData {
  // Grafik için ham veri noktaları (x, y koordinatları)
  final List<FlSpot> timeSeriesData;
  final List<FlSpot> fftData;

  AxisData({required this.timeSeriesData, required this.fftData});
}

// Ana motor verilerini tutacak model
class MotorData {
  final int id;
  final AxisData xAxis;
  final AxisData yAxis;
  final AxisData zAxis;
  final AxisData resultant;

  MotorData({
    required this.id,
    required this.xAxis,
    required this.yAxis,
    required this.zAxis,
    required this.resultant,
  });
}

class MotorStatusPage extends StatefulWidget {
  const MotorStatusPage({super.key});

  @override
  State<MotorStatusPage> createState() => _MotorStatusPageState();
}

enum AxisType { x, y, z, resultant }

class _MotorStatusPageState extends State<MotorStatusPage> {
  int _selectedMotorId = 1;
  AxisType _selectedAxis = AxisType.x;
  MotorData? _currentMotorData;
  bool _isLoading = true;

  // --- SAHTE VERİTABANI GRAFİK VERİLERİ İLE GÜNCELLENDİ ---
  final Map<int, MotorData> _mockMotorDatabase = {};

  @override
  void initState() {
    super.initState();
    _generateAllMockData(); // Tüm sahte verileri oluştur
    _fetchMotorData(_selectedMotorId);
  }

  // Sahte grafik verileri oluşturan yardımcı fonksiyon
  List<FlSpot> _generateFakeSpots(
    int count,
    double maxVal, {
    bool isSin = false,
  }) {
    final List<FlSpot> spots = [];
    final random = Random();
    for (int i = 0; i < count; i++) {
      double y;
      if (isSin) {
        y =
            (sin(i * 0.5) + 1) * (maxVal / 2) +
            random.nextDouble() * (maxVal / 5);
      } else {
        y = random.nextDouble() * maxVal;
      }
      spots.add(FlSpot(i.toDouble(), y));
    }
    return spots;
  }

  // Tüm motorlar için sahte veri üreten ana fonksiyon
  void _generateAllMockData() {
    for (int i = 1; i <= 4; i++) {
      _mockMotorDatabase[i] = MotorData(
        id: i,
        xAxis: AxisData(
          timeSeriesData: _generateFakeSpots(50, 4.0 * i, isSin: true),
          fftData: _generateFakeSpots(32, 0.8),
        ),
        yAxis: AxisData(
          timeSeriesData: _generateFakeSpots(50, 3.0 * i, isSin: true),
          fftData: _generateFakeSpots(32, 0.7),
        ),
        zAxis: AxisData(
          timeSeriesData: _generateFakeSpots(50, 5.0 * i),
          fftData: _generateFakeSpots(32, 0.9),
        ),
        resultant: AxisData(
          timeSeriesData: _generateFakeSpots(50, 6.0 * i),
          fftData: _generateFakeSpots(32, 1.2),
        ),
      );
    }
  }

  Future<void> _fetchMotorData(int motorId) async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() {
      _currentMotorData = _mockMotorDatabase[motorId];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Motor Durumları"),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildMotorSelectionTabs(),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _currentMotorData == null
                ? const Center(child: Text("Veri bulunamadı."))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // YENİ: Küçültülmüş sol menü
                      _buildAxisSelectionMenu(),
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Colors.white12,
                      ),
                      // YENİ: Grafiklerin olduğu sağ panel
                      Expanded(child: _buildGraphsPanel()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Soldaki menüyü oluşturan fonksiyon (genişlik küçültüldü)
  Widget _buildAxisSelectionMenu() {
    return Container(
      width: 100, // Genişlik küçültüldü
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAxisMenuItem(AxisType.x, "X Ekseni"),
          _buildAxisMenuItem(AxisType.y, "Y Ekseni"),
          _buildAxisMenuItem(AxisType.z, "Z Ekseni"),
          _buildAxisMenuItem(AxisType.resultant, "Bileşke"),
        ],
      ),
    );
  }

  Widget _buildAxisMenuItem(AxisType axis, String label) {
    bool isSelected = _selectedAxis == axis;
    return GestureDetector(
      onTap: () => setState(() => _selectedAxis = axis),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13, // Yazı boyutu küçültüldü
          ),
        ),
      ),
    );
  }

  // YENİ: Grafik panelini oluşturan ana widget
  Widget _buildGraphsPanel() {
    AxisData? data;
    String axisName = "";
    switch (_selectedAxis) {
      case AxisType.x:
        data = _currentMotorData!.xAxis;
        axisName = "X Ekseni";
        break;
      case AxisType.y:
        data = _currentMotorData!.yAxis;
        axisName = "Y Ekseni";
        break;
      case AxisType.z:
        data = _currentMotorData!.zAxis;
        axisName = "Z Ekseni";
        break;
      case AxisType.resultant:
        data = _currentMotorData!.resultant;
        axisName = "Bileşke";
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey<String>("${_selectedMotorId}_${_selectedAxis.name}"),
        padding: const EdgeInsets.only(right: 16.0, left: 8.0, top: 8.0),
        child: Column(
          children: [
            Expanded(
              child: _buildChartContainer(
                title: 'Motor $_selectedMotorId - Zaman Serisi: $axisName',
                chart: _buildTimeSeriesChart(data.timeSeriesData),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildChartContainer(
                title: 'FFT: $axisName (${data.fftData.length} Örnek)',
                chart: _buildFftChart(data.fftData),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // YENİ: Tek bir grafik ve başlığını içeren container
  Widget _buildChartContainer({required String title, required Widget chart}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 4.0),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: chart),
        ],
      ),
    );
  }

  // YENİ: Zaman Serisi grafiğini oluşturan fonksiyon
  Widget _buildTimeSeriesChart(List<FlSpot> spots) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 10,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.white24),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.cyanAccent,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.cyan.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  // YENİ: FFT grafiğini oluşturan fonksiyon
  Widget _buildFftChart(List<FlSpot> spots) {
    return LineChart(
      LineChartData(
        // Kırmızı eşik çizgisi
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 1.0,
              color: Colors.redAccent.withOpacity(0.8),
              strokeWidth: 2,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                labelResolver: (_) => 'Eşik (1.00)',
                alignment: Alignment.topRight,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ),
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 20,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 0.2,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.white24),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: Colors.orangeAccent,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  // Bu widget'ı önceki haliyle bıraktım, eğer başka yerde kullanılıyorsa
  Widget _buildMotorSelectionTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      color: Colors.black.withOpacity(0.2),
      child: Row(
        children: List.generate(4, (index) {
          int motorId = index + 1;
          bool isSelected = _selectedMotorId == motorId;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedMotorId = motorId);
                _fetchMotorData(motorId);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    "Motor $motorId",
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
