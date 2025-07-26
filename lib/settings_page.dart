// lib/settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uptime_monitor_final/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settingsService = SettingsService();
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Kayıtlı değerlerle text alanlarını başlat
    _minController = TextEditingController(
      text: _settingsService.getMinValue().toString(),
    );
    _maxController = TextEditingController(
      text: _settingsService.getMaxValue().toString(),
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      final double? minValue = double.tryParse(_minController.text);
      final double? maxValue = double.tryParse(_maxController.text);

      if (minValue != null && maxValue != null) {
        if (minValue >= maxValue) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Hata: Minimum değer, maksimum değerden küçük olmalıdır.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        _settingsService.setMinValue(minValue);
        _settingsService.setMaxValue(maxValue);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ayarlar başarıyla kaydedildi!'),
            backgroundColor: Colors.green,
          ),
        );
        // Klavyeyi kapat
        FocusScope.of(context).unfocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: const Color(0xFF161625),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            const Text(
              'Motor Veri Eşikleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gelen veriler bu aralığın dışına çıktığında motor durum göstergesi kırmızı yanacaktır.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _minController,
              label: 'Minimum Değer',
              icon: Icons.arrow_downward,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _maxController,
              label: 'Maksimum Değer',
              icon: Icons.arrow_upward,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('Ayarları Kaydet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Bu alan boş bırakılamaz';
        }
        if (double.tryParse(value) == null) {
          return 'Lütfen geçerli bir sayı girin';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: const Color(0xFF161625).withOpacity(0.5),
      ),
    );
  }
}
