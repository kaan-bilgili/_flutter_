import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://192.168.1.100:8000';

  Future<List<double>> fetchHistory({int limit = 50}) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/readings/?limit=$limit'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> readings = body['data'] as List<dynamic>;
        return readings.reversed
            .map<double>((r) => (r['temp'] as num).toDouble())
            .toList();
      }
    } catch (e) {
      print('ApiService fetchHistory error: $e');
    }
    return [];
  }

  Future<void> sendSetpoint(double setpoint) async {
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/commands/setpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'setpoint': setpoint}),
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      print('ApiService sendSetpoint error: $e');
    }
  }

  Future<Map<String, double>> fetchWeekly() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/readings/weekly'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> data = body['data'] as List<dynamic>;
        return {
          for (var r in data)
            (r['day'] as String).substring(5): // "05-09" formatı
                (r['avg_temp'] as num).toDouble()
        };
      }
    } catch (e) {
      print('ApiService fetchWeekly error: $e');
    }
    return {};
  }

}
