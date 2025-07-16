// lib/models/recorded_session.dart
import 'package:fl_chart/fl_chart.dart';

class RecordedSession {
  final String id; // Oturum için benzersiz kimlik (örneğin timestamp)
  final DateTime timestamp; // Oturumun kaydedildiği zaman
  final List<FlSpot> motor1Data;
  final List<FlSpot> motor2Data;
  final List<FlSpot> motor3Data;
  final List<FlSpot> motor4Data;

  RecordedSession({
    required this.id,
    required this.timestamp,
    required this.motor1Data,
    required this.motor2Data,
    required this.motor3Data,
    required this.motor4Data,
  });

  // RecordedSession nesnesini JSON'a dönüştürme
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(), // Tarihi ISO formatında kaydet
      'motor1Data': motor1Data
          .map((spot) => {'x': spot.x, 'y': spot.y})
          .toList(),
      'motor2Data': motor2Data
          .map((spot) => {'x': spot.x, 'y': spot.y})
          .toList(),
      'motor3Data': motor3Data
          .map((spot) => {'x': spot.x, 'y': spot.y})
          .toList(),
      'motor4Data': motor4Data
          .map((spot) => {'x': spot.x, 'y': spot.y})
          .toList(),
    };
  }

  // JSON'dan RecordedSession nesnesi oluşturma
  factory RecordedSession.fromJson(Map<String, dynamic> json) {
    return RecordedSession(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      motor1Data: (json['motor1Data'] as List)
          .map(
            (item) => FlSpot(
              (item as Map<String, dynamic>)['x'] as double,
              (item)['y'] as double,
            ),
          )
          .toList(),
      motor2Data: (json['motor2Data'] as List)
          .map(
            (item) => FlSpot(
              (item as Map<String, dynamic>)['x'] as double,
              (item)['y'] as double,
            ),
          )
          .toList(),
      motor3Data: (json['motor3Data'] as List)
          .map(
            (item) => FlSpot(
              (item as Map<String, dynamic>)['x'] as double,
              (item)['y'] as double,
            ),
          )
          .toList(),
      motor4Data: (json['motor4Data'] as List)
          .map(
            (item) => FlSpot(
              (item as Map<String, dynamic>)['x'] as double,
              (item)['y'] as double,
            ),
          )
          .toList(),
    );
  }
}
