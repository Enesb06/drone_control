// lib/pages/saved_graphs_page.dart (GÜNCELLENMİŞ HALİ)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uptime_monitor_final/recorded_session.dart';
import 'package:uptime_monitor_final/view_recorded_graph_page.dart';

class SavedGraphsPage extends StatefulWidget {
  const SavedGraphsPage({super.key});

  @override
  State<SavedGraphsPage> createState() => _SavedGraphsPageState();
}

class _SavedGraphsPageState extends State<SavedGraphsPage> {
  List<RecordedSession> _savedSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedSessions();
  }

  Future<void> _loadSavedSessions() async {
    setState(() => _isLoading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.json'),
      );

      List<RecordedSession> loadedSessions = [];
      for (var file in files) {
        try {
          final jsonString = await file.readAsString();
          final jsonMap = jsonDecode(jsonString);
          if (jsonMap.containsKey('id') && jsonMap.containsKey('timestamp')) {
            loadedSessions.add(RecordedSession.fromJson(jsonMap));
          }
        } catch (e) {
          print('Oturum yüklenirken hata oluştu ${file.path}: $e');
        }
      }

      loadedSessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) {
        setState(() {
          _savedSessions = loadedSessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kayıtlar yüklenemedi: $e')));
      }
    }
  }

  // --- SİLME FONKSİYONU (GÜNCELLENDİ) ---
  Future<void> _deleteSession(RecordedSession session) async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      // === DEĞİŞİKLİK BURADA ===
      // Dosya adını, tıpkı kaydederken olduğu gibi, session.id kullanarak oluşturuyoruz.
      final fileName = 'session_${session.id}.json';
      final file = File('${directory.path}/$fileName');
      // ========================

      if (await file.exists()) {
        await file.delete();
        // Listeyi yeniden yüklemek yerine state'ten çıkarıyoruz (daha verimli).
        setState(() {
          _savedSessions.removeWhere((s) => s.id == session.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Oturum başarıyla silindi.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: Dosya bulunamadı!\nAranan: $fileName'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Oturum silinirken hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Kaydedilen Grafikler'),
        backgroundColor: const Color(0xFF161625),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedSessions,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : _savedSessions.isEmpty
          ? const Center(
              child: Text(
                'Henüz kaydedilmiş grafik yok.',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _savedSessions.length,
              itemBuilder: (context, index) {
                final session = _savedSessions[index];
                return Card(
                  color: const Color(0xFF161625).withOpacity(0.7),
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 4,
                  child: ListTile(
                    title: Text(
                      'Oturum: ${session.timestamp.toLocal().toString().substring(0, 16)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Veri Noktaları: ${session.motor1Data.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () async {
                        final bool? confirm = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            backgroundColor: const Color(0xFF1A1A2E),
                            title: const Text(
                              'Oturumu Sil',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'Bu oturumu silmek istediğinizden emin misiniz?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text(
                                  'İptal',
                                  style: TextStyle(color: Colors.blueAccent),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text(
                                  'Sil',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          _deleteSession(session);
                        }
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ViewRecordedGraphPage(session: session),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
