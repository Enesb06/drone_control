// lib/pages/saved_graphs_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uptime_monitor_final/recorded_session.dart'; // Yolunuzu ayarlayın
import 'package:uptime_monitor_final/view_recorded_graph_page.dart'; // Yeni sayfayı import edin (oluşturacağız)

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
    setState(() {
      _isLoading = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.json') && file.path.contains('session_'),
      );

      List<RecordedSession> loadedSessions = [];
      for (var file in files) {
        try {
          final jsonString = await file.readAsString();
          final jsonMap = jsonDecode(jsonString);
          loadedSessions.add(RecordedSession.fromJson(jsonMap));
        } catch (e) {
          print('Error loading session from ${file.path}: $e');
        }
      }

      // En yeni oturumlar üstte olacak şekilde sırala
      loadedSessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _savedSessions = loadedSessions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error accessing application directory: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kaydedilen oturumlar yüklenirken hata oluştu: $e'),
          ),
        );
      }
    }
  }

  // YENİ: Oturum silme fonksiyonu
  Future<void> _deleteSession(String sessionId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'session_${sessionId.replaceAll(':', '-')}.json'; // Dosya adı formatı önemli
      final file = File('${directory.path}/$fileName');

      if (await file.exists()) {
        await file.delete();
        await _loadSavedSessions(); // Listeyi yeniden yükle
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Oturum başarıyla silindi.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Silinecek oturum dosyası bulunamadı.'),
            ),
          );
        }
      }
    } catch (e) {
      print('Oturum silinirken hata oluştu: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Oturum silinirken hata oluştu: $e')),
        );
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
                      'Oturum: ${session.timestamp.toLocal().toIso8601String().split('.')[0].replaceAll('T', ' ')}',
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
                          builder: (BuildContext context) {
                            return AlertDialog(
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
                            );
                          },
                        );
                        if (confirm == true) {
                          _deleteSession(session.id);
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
