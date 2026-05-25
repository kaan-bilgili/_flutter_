import 'package:flutter/material.dart';
import 'dart:math';
import 'mqtt_service.dart';
import 'api_service.dart';

class GraphsPage extends StatefulWidget {
  const GraphsPage({super.key});

  @override
  State<GraphsPage> createState() => _GraphsPageState();
}

class _GraphsPageState extends State<GraphsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double>   _animation;

  late MQTTService _mqttService;
  late ApiService  _apiService;

  List<double> dynamicTemps = [];
  bool _isLoading = true;

  // Statik fallback veriler (API/MQTT yoksa gösterilir)
  final List<double> hourlyTemps = [
    24.5, 24.0, 23.5, 23.0, 22.8, 22.5, 23.0, 24.0,
    25.5, 26.0, 26.5, 27.0, 27.5, 27.8, 28.0, 27.5,
    27.0, 26.8, 26.5, 26.0, 25.5, 25.0, 24.8, 24.5,
  ];
  final List<double> weeklyTemps = [23.5, 25.0, 26.5, 27.0, 24.0, 22.5, 25.5];
  final List<String> weekDays    = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _mqttService = MQTTService();
    _apiService  = ApiService();

    // MQTT: canlı veri gelince listeye ekle (API geçmişin üzerine)
    _mqttService.onTemperatureChanged = (temp) {
      if (!mounted) return;
      setState(() {
        dynamicTemps.add(temp);
        if (dynamicTemps.length > 24) dynamicTemps.removeAt(0);
      });
    };

    // API: sayfa açılınca geçmiş veriyi çek
    _loadHistory();
  }

  // ─── API'den geçmiş yükle ─────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    final history = await _apiService.fetchHistory(limit: 24);
    if (!mounted) return;
    setState(() {
      if (history.isNotEmpty) dynamicTemps = history;
      _isLoading = false;
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    _mqttService.onTemperatureChanged = null;
    _apiService.stopPolling();
    _animationController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    setState(() => _selectedTab = index);
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final currentData = dynamicTemps.isEmpty ? hourlyTemps : dynamicTemps;
    final minTemp = currentData.reduce(min);
    final maxTemp = currentData.reduce(max);
    final avgTemp = currentData.reduce((a, b) => a + b) / currentData.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'ThermoSmart',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('Kontes Room', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        actions: [
          Row(
            children: [
              const Icon(Icons.thermostat, color: Colors.white70, size: 20),
              const SizedBox(width: 4),
              Text(
                '${currentData.last.toStringAsFixed(1)} °C',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Temperature Graphs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Historical temperature data',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Tab bar
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141929),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          _buildTab('Last 24 Hours', 0),
                          _buildTab('Weekly', 1),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Stat kartları
                    Row(
                      children: [
                        _buildStatCard('Min', '${minTemp.toStringAsFixed(1)}°C', const Color(0xFF3B82F6)),
                        const SizedBox(width: 12),
                        _buildStatCard('Max', '${maxTemp.toStringAsFixed(1)}°C', const Color(0xFF6366F1)),
                        const SizedBox(width: 12),
                        _buildStatCard('Avg', '${avgTemp.toStringAsFixed(1)}°C', const Color(0xFF8B5CF6)),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Grafik
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141929),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedTab == 0 ? '24-Hour Overview' : '7-Day Overview',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              // Veri kaynağı göstergesi
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: dynamicTemps.isNotEmpty
                                      ? const Color(0xFF2ECC71).withOpacity(0.1)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: dynamicTemps.isNotEmpty
                                        ? const Color(0xFF2ECC71).withOpacity(0.3)
                                        : Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Text(
                                  dynamicTemps.isNotEmpty ? 'API data' : 'sample data',
                                  style: TextStyle(
                                    color: dynamicTemps.isNotEmpty
                                        ? const Color(0xFF2ECC71)
                                        : Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 200,
                            child: AnimatedBuilder(
                              animation: _animation,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: TemperatureChartPainter(
                                    data: _selectedTab == 0 ? currentData : weeklyTemps,
                                    labels: _selectedTab == 1 ? weekDays : null,
                                    progress: _animation.value,
                                  ),
                                  size: Size.infinite,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Son sıcaklık kartı
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A5F), Color(0xFF141929)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.thermostat, color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            '${currentData.last.toStringAsFixed(1)} °C',
                            style: const TextStyle(color: Colors.white, fontSize: 22),
                          ),
                          const Spacer(),
                          const Text(
                            'latest reading',
                            style: TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const SizedBox(height: 80),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(color: isSelected ? Colors.white : Colors.white38),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF141929),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white38)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ─── Chart Painter ────────────────────────────────────────────────────────────

class TemperatureChartPainter extends CustomPainter {
  final List<double> data;
  final List<String>? labels;
  final double progress;

  TemperatureChartPainter({
    required this.data,
    this.labels,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double minVal = data.reduce(min) - 1;
    final double maxVal = data.reduce(max) + 1;
    final double range  = maxVal - minVal;
    final int visibleCount = (data.length * progress).ceil().clamp(2, data.length);

    final double stepX    = size.width / (data.length - 1);
    const double labelHeight = 20.0;
    final double chartHeight = size.height - labelHeight;

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF1E2A40)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = chartHeight * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Points
    final List<Offset> points = [];
    for (int i = 0; i < visibleCount; i++) {
      final x = i * stepX;
      final y = chartHeight * (1 - (data[i] - minVal) / range);
      points.add(Offset(x, y));
    }

    if (points.length < 2) return;

    // Fill area
    final fillPath = Path()..moveTo(points.first.dx, chartHeight);
    fillPath.lineTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      fillPath.lineTo(points[i].dx, points[i].dy);
    }
    fillPath.lineTo(points.last.dx, chartHeight);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF3B82F6).withOpacity(0.3),
            const Color(0xFF3B82F6).withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight)),
    );

    // Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = const Color(0xFF3B82F6)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    // Son nokta dot
    canvas.drawCircle(
      points.last,
      4,
      Paint()..color = const Color(0xFF3B82F6),
    );
  }

  @override
  bool shouldRepaint(covariant TemperatureChartPainter oldDelegate) => true;
}