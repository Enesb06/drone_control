// lib/pages/view_recorded_graph_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:uptime_monitor_final/recorded_session.dart'; // Yolunuzu ayarlayın

class ViewRecordedGraphPage extends StatefulWidget {
  final RecordedSession session;

  const ViewRecordedGraphPage({super.key, required this.session});

  @override
  State<ViewRecordedGraphPage> createState() => _ViewRecordedGraphPageState();
}

class _ViewRecordedGraphPageState extends State<ViewRecordedGraphPage> {
  int _currentPageIndex = 0; // 0: MTR1, 1: MTR2, 2: MTR3, 3: MTR4

  // Motor verilerini RecordedSession'dan alıyoruz
  late final List<FlSpot> _motor1Data;
  late final List<FlSpot> _motor2Data;
  late final List<FlSpot> _motor3Data;
  late final List<FlSpot> _motor4Data;

  @override
  void initState() {
    super.initState();
    _motor1Data = widget.session.motor1Data;
    _motor2Data = widget.session.motor2Data;
    _motor3Data = widget.session.motor3Data;
    _motor4Data = widget.session.motor4Data;
  }

  // Sayfaların başlıklarını döndüren yardımcı fonksiyon
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
    // Grafiğin X ekseni aralığını belirle
    double minX = 0;
    double maxX = 0;

    // Tüm motor verilerinden en büyük X değerini bul
    final allData = [
      ..._motor1Data,
      ..._motor2Data,
      ..._motor3Data,
      ..._motor4Data,
    ];

    if (allData.isNotEmpty) {
      allData.sort((a, b) => a.x.compareTo(b.x)); // X değerine göre sırala
      minX = allData.first.x;
      maxX = allData.last.x;
    } else {
      // Veri yoksa varsayılan bir aralık belirle
      minX = 0;
      maxX = 5; // Örneğin 5 saniye
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text('${_getPageTitle(_currentPageIndex)} (Kaydedildi)'),
        backgroundColor: const Color(0xFF161625),
        elevation: 4,
      ),
      body: Column(
        children: [
          // Sayfa Seçim Butonları
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
                // Her sayfa için kaydedilmiş veriyi kullanarak grafik oluştur
                _buildGraphContent(
                  _motor1Data,
                  minX,
                  maxX,
                ), // Motor 1'in kaydedilen verisi
                _buildGraphContent(
                  _motor2Data,
                  minX,
                  maxX,
                ), // Motor 2'nin kaydedilen verisi
                _buildGraphContent(
                  _motor3Data,
                  minX,
                  maxX,
                ), // Motor 3'ün kaydedilen verisi
                _buildGraphContent(
                  _motor4Data,
                  minX,
                  maxX,
                ), // Motor 4'ün kaydedilen verisi
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      child: Text(text),
    );
  }

  // --- Her sayfa için kullanılacak grafik içeriği ---
  // Hangi veri listesini göstereceğini parametre olarak alıyor
  Widget _buildGraphContent(
    List<FlSpot> spotsToDisplay,
    double minX,
    double maxX,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 0.0,
        left: 16.0,
        right: 16.0,
        bottom: 16.0,
      ),
      child: Column(
        children: [Expanded(child: _buildChart(minX, maxX, spotsToDisplay))],
      ),
    );
  }

  // Statik Grafik Oluşturucu Widget'ı (Canlı grafiğe benziyor ama zaman kaydırması yok)
  Widget _buildChart(
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
              child: Text(
                'Bu oturum için kaydedilmiş veri yok.',
                style: TextStyle(color: Colors.white54),
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
                // Kaydedilmiş grafiklerde animasyon olmamalı
                duration: Duration.zero,
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
