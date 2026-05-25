import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://192.168.1.100:8000';

  /// Called whenever a new reading is successfully fetched.
  Function(double temp, double humidity)? onReadingReceived;

  Timer? _pollingTimer;

  // ---------------------------------------------------------------------------
  // Polling
  // ---------------------------------------------------------------------------

  /// Start polling [GET /readings/latest] every [interval].
  /// Fires an immediate request before the first interval elapses.
  void startPolling({Duration interval = const Duration(seconds: 5)}) {
    _pollingTimer?.cancel();
    _fetchLatest(); // fire immediately
    _pollingTimer = Timer.periodic(interval, (_) => _fetchLatest());
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // ---------------------------------------------------------------------------
  // GET /readings/latest
  // ---------------------------------------------------------------------------

  Future<void> _fetchLatest() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/readings/latest'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['temp'] != null && data['humidity'] != null) {
          final temp = (data['temp'] as num).toDouble();
          final humidity = (data['humidity'] as num).toDouble();
          onReadingReceived?.call(temp, humidity);
        }
      }
    } catch (e) {
      print('ApiService polling error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // GET /readings/?limit=N  →  historical temperature list (oldest → newest)
  // ---------------------------------------------------------------------------

  Future<List<double>> fetchHistory({int limit = 50}) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/readings/?limit=$limit'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> readings = body['data'] as List<dynamic>;
        // API returns newest-first; reverse for a left-to-right chronological chart.
        return readings.reversed
            .map<double>((r) => (r['temp'] as num).toDouble())
            .toList();
      }
    } catch (e) {
      print('ApiService fetchHistory error: $e');
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // POST /commands/setpoint
  // ---------------------------------------------------------------------------

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
}
