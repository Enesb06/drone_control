import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

// --- VERİ MODELLERİ GÜNCELLENDİ ---

// Tek bir eksenin verilerini tutacak alt model
class AxisData {
  final double vibration; // Titreşim (mm/s)
  final double displacement; // Yer Değiştirme (μm)
  final int peak; // Zirve Değer (g)

  AxisData({
    required this.vibration,
    required this.displacement,
    required this.peak,
  });
}

// Ana motor verilerini tutacak model, artık eksen verilerini içeriyor
class MotorData {
  final int id;
  final AxisData xAxis;
  final AxisData yAxis;
  final AxisData zAxis;
  final AxisData resultant; // Bileşke

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

// Seçilebilecek eksenleri tanımlayan bir enum
enum AxisType { x, y, z, resultant }

class _MotorStatusPageState extends State<MotorStatusPage> {
  int _selectedMotorId = 1; // Hangi motorun seçili olduğu
  AxisType _selectedAxis = AxisType.x; // Hangi eksenin seçili olduğu
  MotorData? _currentMotorData;
  bool _isLoading = true;

  // --- SAHTE VERİTABANI GÜNCELLENDİ ---
  // Her motor için artık 4 farklı eksen verisi içeriyor
  final Map<int, MotorData> _mockMotorDatabase = {
    1: MotorData(
      id: 1,
      xAxis: AxisData(vibration: 2.5, displacement: 15.2, peak: 1),
      yAxis: AxisData(vibration: 1.8, displacement: 12.1, peak: 1),
      zAxis: AxisData(vibration: 3.1, displacement: 18.5, peak: 2),
      resultant: AxisData(vibration: 4.2, displacement: 25.3, peak: 2),
    ),
    2: MotorData(
      id: 2,
      xAxis: AxisData(vibration: 4.1, displacement: 22.0, peak: 3),
      yAxis: AxisData(vibration: 3.5, displacement: 19.8, peak: 2),
      zAxis: AxisData(vibration: 5.2, displacement: 30.1, peak: 4),
      resultant: AxisData(vibration: 7.5, displacement: 41.7, peak: 5),
    ),
    3: MotorData(
      id: 3,
      xAxis: AxisData(vibration: 0.5, displacement: 3.2, peak: 0),
      yAxis: AxisData(vibration: 0.4, displacement: 2.8, peak: 0),
      zAxis: AxisData(vibration: 0.6, displacement: 4.1, peak: 0),
      resultant: AxisData(vibration: 0.9, displacement: 5.8, peak: 0),
    ),
    4: MotorData(
      id: 4,
      xAxis: AxisData(vibration: 8.9, displacement: 50.3, peak: 7),
      yAxis: AxisData(vibration: 7.2, displacement: 45.1, peak: 6),
      zAxis: AxisData(vibration: 10.5, displacement: 62.4, peak: 9),
      resultant: AxisData(vibration: 15.3, displacement: 89.9, peak: 10),
    ),
  };

  @override
  void initState() {
    super.initState();
    _fetchMotorData(_selectedMotorId);
  }

  Future<void> _fetchMotorData(int motorId) async {
    setState(() {
      _isLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 400));
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
          // Üstteki Motor Seçim Sekmeleri
          _buildMotorSelectionTabs(),
          const SizedBox(height: 16),
          // Ana İçerik Alanı (Sol Menü + Sağ Veri Paneli)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _currentMotorData == null
                ? const Center(child: Text("Veri bulunamadı."))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sol Dikey Eksen Menüsü
                      _buildAxisSelectionMenu(),
                      // Dikey ayırıcı çizgi
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Colors.white24,
                      ),
                      // Sağ Veri Gösterim Alanı
                      Expanded(child: _buildAxisInfoPanel()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Üst Motor sekmelerini oluşturan fonksiyon
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

  // Sol dikey menüyü oluşturan fonksiyon
  Widget _buildAxisSelectionMenu() {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAxisMenuItem(AxisType.x, "X Ekseni"),
          _buildAxisMenuItem(AxisType.y, "Y Ekseni"),
          _buildAxisMenuItem(AxisType.z, "Z Ekseni"),
          const Divider(height: 32, indent: 16, endIndent: 16),
          _buildAxisMenuItem(AxisType.resultant, "Bileşke"),
        ],
      ),
    );
  }

  // Sol menüdeki tek bir elemanı oluşturan fonksiyon
  Widget _buildAxisMenuItem(AxisType axis, String label) {
    bool isSelected = _selectedAxis == axis;
    return GestureDetector(
      onTap: () => setState(() => _selectedAxis = axis),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Seçim radyo butonu
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.blueAccent : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 8),
            // Metin
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sağdaki veri paneli
  Widget _buildAxisInfoPanel() {
    // Gösterilecek doğru eksen verisini al
    AxisData? data;
    switch (_selectedAxis) {
      case AxisType.x:
        data = _currentMotorData!.xAxis;
        break;
      case AxisType.y:
        data = _currentMotorData!.yAxis;
        break;
      case AxisType.z:
        data = _currentMotorData!.zAxis;
        break;
      case AxisType.resultant:
        data = _currentMotorData!.resultant;
        break;
    }

    // Geçiş animasyonu için
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Container(
        // Key, Flutter'a widget'ın değiştiğini ve animasyonu tetiklemesi gerektiğini söyler
        key: ValueKey<AxisType>(_selectedAxis),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _infoTile(
              icon: Icons.vibration,
              label: "Titreşim",
              value: "${data.vibration.toStringAsFixed(1)} mm/s",
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 20),
            _infoTile(
              icon: Icons.open_with_rounded,
              label: "Yer Değiştirme",
              value: "${data.displacement.toStringAsFixed(1)} µm",
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 20),
            _infoTile(
              icon: Icons.show_chart_rounded,
              label: "Zirve (Peak)",
              value: "${data.peak} g",
              color: Colors.pinkAccent,
            ),
          ],
        ),
      ),
    );
  }

  // Bilgi satırlarını oluşturan widget (değişiklik yok)
  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
