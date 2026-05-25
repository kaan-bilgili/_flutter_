import 'package:flutter/material.dart';
import 'dart:math';
import 'api_service.dart';
import 'mqtt_service.dart';

class GraphsPage extends StatefulWidget {
  const GraphsPage({super.key});

  @override
  State<GraphsPage> createState() => _GraphsPageState();
}

class _GraphsPageState extends State<GraphsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  List<double> dynamicTemps  = [];
  List<String> dynamicLabels = [];
  Map<String, double> weeklyData = {};
  bool _isLoading = true;
  double _liveTemp = 0;

  Function(double)? _previousCallback;

  final List<double> hourlyTemps = [
    24.5, 24.0, 23.5, 23.0, 22.8, 22.5, 23.0, 24.0,
    25.5, 26.0, 26.5, 27.0, 27.5, 27.8, 28.0, 27.5,
    27.0, 26.8, 26.5, 26.0, 25.5, 25.0, 24.8, 24.5,
  ];

  List<double> get weeklyTemps => weeklyData.values.toList();
  List<String> get weekDays    => weeklyData.keys.toList();

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

    _previousCallback = MQTTService().onTemperatureChanged;
    MQTTService().onTemperatureChanged = (temp) {
      _previousCallback?.call(temp);
      if (!mounted) return;
      setState(() => _liveTemp = temp);
    };

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await ApiService().fetchHistory(limit: 24);
    final weekly  = await ApiService().fetchWeekly();
    if (!mounted) return;
    setState(() {
      if (history.isNotEmpty) {
        dynamicTemps  = history.map((r) => r['temp'] as double).toList();
        dynamicLabels = history.map((r) {
          final ts = r['timestamp'] as String;
          if (ts.isEmpty) return '';
          try {
            final dt = DateTime.parse(ts).toLocal();
            return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          } catch (_) { return ''; }
        }).toList();
      }
      if (weekly.isNotEmpty) weeklyData = weekly;
      _isLoading = false;
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    MQTTService().onTemperatureChanged = _previousCallback;
    _animationController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    setState(() => _selectedTab = index);
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final currentTemps  = dynamicTemps.isEmpty ? hourlyTemps : dynamicTemps;
    final currentLabels = dynamicLabels.isEmpty
        ? List<String>.filled(hourlyTemps.length, '')
        : dynamicLabels;

    final chartTemps  = _selectedTab == 0 ? currentTemps  : (weeklyTemps.isEmpty ? hourlyTemps : weeklyTemps);
    final chartLabels = _selectedTab == 0 ? currentLabels : weekDays;

    final displayTemp = _liveTemp > 0 ? _liveTemp : currentTemps.last;

    final minTemp = chartTemps.isEmpty ? 0.0 : chartTemps.reduce(min);
    final maxTemp = chartTemps.isEmpty ? 0.0 : chartTemps.reduce(max);
    final avgTemp = chartTemps.isEmpty ? 0.0 : chartTemps.reduce((a, b) => a + b) / chartTemps.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ThermoSmart',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Kontes Room',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        actions: [
          Row(
            children: [
              const Icon(Icons.thermostat, color: Colors.white70, size: 20),
              const SizedBox(width: 4),
              Text('${displayTemp.toStringAsFixed(1)} C',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                onPressed: () async {
                  setState(() {
                    _isLoading = true;
                    dynamicTemps  = [];
                    dynamicLabels = [];
                    weeklyData    = {};
                  });
                  await _loadHistory();
                },
              ),
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
                    const Text('Temperature Graphs',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    const Text('Historical temperature data',
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                    const SizedBox(height: 24),

                    // Tab
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141929),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(children: [
                        _buildTab('Last 24 Readings', 0),
                        _buildTab('Weekly', 1),
                      ]),
                    ),
                    const SizedBox(height: 28),

                    // Stat kartları — gerçek veriyle
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
                            color: const Color(0xFF3B82F6).withOpacity(0.2), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedTab == 0 ? 'Last 24 Readings' : '7-Day Overview',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 240,
                            child: AnimatedBuilder(
                              animation: _animation,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: TemperatureChartPainter(
                                    data: chartTemps,
                                    labels: chartLabels,
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

                    // Alt kart
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A5F), Color(0xFF141929)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.thermostat, color: Colors.white),
                          const SizedBox(width: 12),
                          Text('${displayTemp.toStringAsFixed(1)} °C',
                              style: const TextStyle(color: Colors.white, fontSize: 22)),
                          const Spacer(),
                          Text(_liveTemp > 0 ? 'live' : 'last reading',
                              style: const TextStyle(color: Colors.white38, fontSize: 11)),
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
          child: Text(label,
              style: TextStyle(color: isSelected ? Colors.white : Colors.white38)),
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
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ─── Chart Painter ────────────────────────────────────────────────────────────

class TemperatureChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final double progress;

  TemperatureChartPainter({
    required this.data,
    required this.labels,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    const double yLabelWidth = 36.0;
    const double xLabelHeight = 24.0;
    final double chartWidth  = size.width - yLabelWidth;
    final double chartHeight = size.height - xLabelHeight;

    final double minVal = data.reduce(min) - 1;
    final double maxVal = data.reduce(max) + 1;
    final double range  = (maxVal - minVal) == 0 ? 1 : maxVal - minVal;
    final int visibleCount = (data.length * progress).ceil().clamp(2, data.length);
    final double stepX = chartWidth / (data.length - 1);

    // ── Grid + Y etiketleri ──────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = const Color(0xFF1E2A40)
      ..strokeWidth = 1;

    const yLabelStyle = TextStyle(color: Color(0xFF4A6080), fontSize: 9);

    for (int i = 0; i <= 4; i++) {
      final y = chartHeight * (1 - i / 4);
      // Grid çizgisi
      canvas.drawLine(
        Offset(yLabelWidth, y),
        Offset(size.width, y),
        gridPaint,
      );
      // Y etiketi (derece değeri)
      final tempVal = minVal + (range * i / 4);
      final tp = TextPainter(
        text: TextSpan(text: '${tempVal.toStringAsFixed(0)}°', style: yLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // ── Noktalar ─────────────────────────────────────────────────────────────
    final List<Offset> points = [];
    for (int i = 0; i < visibleCount; i++) {
      final x = yLabelWidth + i * stepX;
      final y = chartHeight * (1 - (data[i] - minVal) / range);
      points.add(Offset(x, y));
    }

    if (points.length < 2) return;

    // ── Fill ─────────────────────────────────────────────────────────────────
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
        ).createShader(Rect.fromLTWH(yLabelWidth, 0, chartWidth, chartHeight)),
    );

    // ── Line ─────────────────────────────────────────────────────────────────
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
    canvas.drawCircle(points.last, 4, Paint()..color = const Color(0xFF3B82F6));

    // ── X etiketleri ─────────────────────────────────────────────────────────
    if (labels.isEmpty) return;
    const xLabelStyle = TextStyle(color: Color(0xFF4A6080), fontSize: 9);
    final int step = (data.length / 6).ceil().clamp(1, data.length);
    final Set<int> drawn = {};

    for (int i = 0; i < visibleCount; i += step) {
      if (i >= labels.length || labels[i].isEmpty) continue;
      drawn.add(i);
      final x = yLabelWidth + i * stepX;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: xLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartHeight + 6));
    }

    // Son etiketi her zaman göster
    final lastIdx = visibleCount - 1;
    if (lastIdx < labels.length && labels[lastIdx].isNotEmpty && !drawn.contains(lastIdx)) {
      final x = yLabelWidth + lastIdx * stepX;
      final tp = TextPainter(
        text: TextSpan(text: labels[lastIdx], style: xLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(covariant TemperatureChartPainter oldDelegate) => true;
}