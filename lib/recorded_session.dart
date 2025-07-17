// lib/models/recorded_session.dart

import 'package:fl_chart/fl_chart.dart';

class RecordedSession {
  final String id;
  final DateTime timestamp;
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
    List<Map<String, double>> spotsToJson(List<FlSpot> spots) {
      return spots.map((spot) => {'x': spot.x, 'y': spot.y}).toList();
    }

    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'motor1Data': spotsToJson(motor1Data),
      'motor2Data': spotsToJson(motor2Data),
      'motor3Data': spotsToJson(motor3Data),
      'motor4Data': spotsToJson(motor4Data),
    };
  }

  // JSON'dan RecordedSession nesnesi oluşturma (GÜVENLİ HALE GETİRİLDİ)
  factory RecordedSession.fromJson(Map<String, dynamic> json) {
    List<FlSpot> jsonToSpots(List<dynamic> jsonList) {
      return jsonList.map((item) {
        final pointMap = item as Map<String, dynamic>;
        // 'num' olarak alıp .toDouble() demek, JSON'da 50 veya 50.0 olmasına bakmaksızın çalışır.
        final x = (pointMap['x'] as num).toDouble();
        final y = (pointMap['y'] as num).toDouble();
        return FlSpot(x, y);
      }).toList();
    }

    return RecordedSession(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      motor1Data: jsonToSpots(json['motor1Data'] as List? ?? []),
      motor2Data: jsonToSpots(json['motor2Data'] as List? ?? []),
      motor3Data: jsonToSpots(json['motor3Data'] as List? ?? []),
      motor4Data: jsonToSpots(json['motor4Data'] as List? ?? []),
    );
  }
}
